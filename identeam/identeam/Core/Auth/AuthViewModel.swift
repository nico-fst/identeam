//
//  AuthViewModel.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Combine
import Foundation
import SwiftData
import SwiftUI

enum AuthState: String {
    case unknown = "Unknown Auth State"
    case unauthenticated = "Not Authenticated"
    case enteringUserDetails = "Entering UserDetails..."
    case authenticated = "Authenticated"
}

enum AuthMode: String, CaseIterable, Identifiable {
    case login = "login"
    case signup = "sign up"
    
    var id: String { self.rawValue }
}

class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .unknown
    @Published var authError: String? = nil
    @Published var isAuthing: Bool = false
    
    @Published var nicknameInput: String = ""
    @Published var usernameInput: String = ""
    @Published var emailInput: String = ""
    @Published var passwordInput: String = ""
    
    @Published var signupError: String? = nil

    @AppStorage("userID") private var userID: String?
    @AppStorage("email") private var email: String?
    @AppStorage("nickname") private var nickname: String?
    @AppStorage("username") private var username: String?

    @AppStorage("sessionToken") private var sessionToken: String?

    // triggered by Notification send from RequestService
    private var cancellables = Set<AnyCancellable>()
    init() {
        migrateLegacyNicknameStorage()

        NotificationCenter.default.publisher(for: .didReceiveUnauthorized)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.logout()
            }
            .store(in: &cancellables)
    }

    private func migrateLegacyNicknameStorage() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "nickname") == nil,
              let legacyNickname = defaults.string(forKey: "fullName")
        else { return }

        defaults.set(legacyNickname, forKey: "nickname")
        defaults.removeObject(forKey: "fullName")
    }

    func tryChangeUserDetails() async {
        guard nicknameInput != "", usernameInput != "" else { return }
        
        do {
            let newUser = try await UserAPI.shared
                .requestUserDetailsChange(
                    nickname: nicknameInput,
                    username: usernameInput
                )
            completeChangeUserDetails(newUser: newUser)
        } catch {
            print("Werde error zeigen: ", error.localizedDescription)
            signupError = error.localizedDescription
        }
    }

    @MainActor
    func completeChangeUserDetails(newUser: UserDTO) {
        print("Saving NewUser: \(newUser)")
        self.sessionToken = sessionToken

        self.userID = newUser.userID
        self.email = newUser.email
        self.nickname = newUser.nickname
        self.username = newUser.username

        authState = .authenticated
    }

    /// Sets authState according to backend's response to sessionToken
    func trySiwaLogin(vm: AppViewModel) async {
        guard let token = sessionToken, !token.isEmpty else {
            logout()
            return
        }

        do {
            let response = try await AuthAPI.shared
                .letBackendValidateSessionToken()
            if response.statusCode == 401 {
                logout()
                return
            }

            authState = .authenticated
        } catch {
            vm.showAlert("Authenticating Error", error.localizedDescription)
            logout()
        }
    }
    
    func tryPasswordLoginOrSignup(authMode: AuthMode, vm: AppViewModel) async throws {
        isAuthing = true
        defer { isAuthing = false }
        
        // Validate inputs first; show feedback on MainActor to avoid publishing during view updates
        
        if emailInput.isEmpty || passwordInput.isEmpty {
            throw AuthError.emailOrPasswordMissing
        }

        do {
            let response = try await AuthAPI.shared.sendPasswordFlowToBackend(
                authMode: authMode,
                email: emailInput,
                password: passwordInput
            )
            
            completeLogin(
                sessionToken: response.sessionToken,
                userID: response.user.userID,
                email: response.user.email,
                nickname: response.user.nickname,
                username: response.user.username,
                created: response.created
            )
            
            try await TokenAPI.shared.sendDeviceTokenToBackend()
        } catch {
            throw error
        }
    }

    @MainActor
    func logout(ctx: ModelContext? = nil) {
        userID = nil
        email = nil
        nickname = nil
        username = nil

        sessionToken = nil

        authState = .unauthenticated
        
        if let ctx {
            deleteUserModels(ctx: ctx)
        }
    }
    
    @MainActor
    private func deleteUserModels(ctx: ModelContext) {
        do {
            for team in try ctx.fetch(FetchDescriptor<Team>()) {
                ctx.delete(team)
            }

            for ident in try ctx.fetch(FetchDescriptor<Ident>()) {
                ctx.delete(ident)
            }
            
            for teamMember in try ctx.fetch(FetchDescriptor<TeamMember>()) {
                ctx.delete(teamMember)
            }
            
            for teamWeek in try ctx.fetch(FetchDescriptor<TeamWeek>()) {
                ctx.delete(teamWeek)
            }
            
            for user in try ctx.fetch(FetchDescriptor<User>()) {
                ctx.delete(user)
            }

            for s3Item in try ctx.fetch(FetchDescriptor<S3Item>()) {
                ctx.delete(s3Item)
            }
            
            for comment in try ctx.fetch(FetchDescriptor<Comment>()) {
                ctx.delete(comment)
            }

            try ctx.save()
        } catch {
            authError = error.localizedDescription
        }
    }


    // in SIWA button: not tryLogin() since in async and variables not stable yet
    @MainActor
    func completeLogin(
        sessionToken: String,
        userID: String,
        email: String,
        nickname: String,
        username: String,
        created: Bool  // == user signed up 1st time
    ) {
        print("Saving SessionToken: \(sessionToken)")
        self.sessionToken = sessionToken
        
        if created && self.username != "" {
            // sign up: ask for name, username
            authState = .enteringUserDetails
        } else {
            // login: immediately close login popup
            authState = .authenticated
        }

        self.userID = userID
        self.email = email
        self.nickname = nickname
        self.username = username
        
        self.isAuthing = false
    }
}

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

class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .unknown
    @Published var authError: String? = nil

    @Published var fullnameInput: String = ""
    @Published var usernameInput: String = ""
    @Published var signupError: String? = nil

    @Published var emailInput: String = ""
    @Published var passwordInput: String = ""

    @AppStorage("userID") private var userID: String?
    @AppStorage("email") private var email: String?
    @AppStorage("fullName") private var fullName: String?
    @AppStorage("username") private var username: String?

    @AppStorage("sessionToken") private var sessionToken: String?

    // triggered by Notification send from RequestService
    private var cancellables = Set<AnyCancellable>()
    init() {
        NotificationCenter.default.publisher(for: .didReceiveUnauthorized)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.logout()
            }
            .store(in: &cancellables)
    }

    func tryChangeUserDetails() async {
        do {
            let newUser = try await UserService.shared
                .requestUserDetailsChange(
                    fullName: fullnameInput,
                    username: usernameInput
                )
            completeChangeUserDetails(newUser: newUser)
        } catch {
            print("Werde error zeigen: ", error.localizedDescription)
            signupError = error.localizedDescription
        }
    }

    @MainActor
    func completeChangeUserDetails(newUser: User) {
        print("Saving NewUser: \(newUser)")
        self.sessionToken = sessionToken

        self.userID = newUser.userID
        self.email = newUser.email
        self.fullName = newUser.fullName
        self.username = newUser.username

        authState = .authenticated
    }

    /// Sets authState according to backend's response to sessionToken
    func tryLogin(vm: AppViewModel) async {
        guard let token = sessionToken, !token.isEmpty else {
            logout()
            return
        }

        do {
            let response = try await AuthService.shared
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

    @MainActor
    func logout() {
        userID = nil
        email = nil
        fullName = nil
        username = nil

        sessionToken = nil

        authState = .unauthenticated
    }

    // in SIWA button: not tryLogin() since in async and variables not stable yet
    @MainActor
    func completeLogin(
        sessionToken: String,
        userID: String,
        email: String,
        fullName: String,
        username: String,
        created: Bool  // == user signed up 1st time
    ) {
        print("Saving SessionToken: \(sessionToken)")
        self.sessionToken = sessionToken

        self.userID = userID
        self.email = email
        self.fullName = fullName
        self.username = username

        if created {
            // sign up: ask for name, username
            authState = .enteringUserDetails
        } else {
            // login: immediately close login popup
            authState = .authenticated
        }
    }
}

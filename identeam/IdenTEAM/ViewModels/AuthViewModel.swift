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
    case authenticated = "Authenticated"
}

class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .unknown
    @Published var authError: String? = nil

    @Published var showLoginSheet: Bool = false
    @Published var showEnterUserDetails: Bool = false  // after Sign Up: Ask for name, username

    @Published var fullnameInput: String = ""
    @Published var usernameInput: String = ""
    @Published var signupError: String? = nil

    @AppStorage("userID") private var userID: String?
    @AppStorage("email") private var email: String?
    @AppStorage("fullName") private var fullName: String?
    @AppStorage("username") private var username: String?

    @AppStorage("sessionToken") private var sessionToken: String?

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

        showLoginSheet = false
        showEnterUserDetails = false
    }

    /// Sets authState according to backend's response to sessionToken
    func tryLogin(vm: AppViewModel) async {
        guard let token = sessionToken, !token.isEmpty else {
            authState = .unauthenticated
            showLoginSheet = true
            return
        }

        do {
            let response = try await AuthService.shared
                .letBackendValidateSessionToken()
            if response.statusCode == 401 {
                authState = .unauthenticated
                showLoginSheet = true
                return
            }

            authState = .authenticated
            showLoginSheet = false
        } catch {
            vm.showAlert("Authenticating Error", error.localizedDescription)

            authState = .unauthenticated
            showLoginSheet = true
        }
    }

    func logout() {
        userID = nil
        email = nil
        fullName = nil
        username = nil

        sessionToken = ""

        authState = .unauthenticated
        showLoginSheet = true
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
            showEnterUserDetails = true
        } else {
            // immediately close login popup
            showLoginSheet = false
        }
        authState = .authenticated
    }
}

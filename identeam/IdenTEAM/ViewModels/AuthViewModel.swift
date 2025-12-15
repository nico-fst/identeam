//
//  AuthViewModel.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

internal import Combine
import Foundation
import SwiftUI

enum AuthState: String {
    case unknown = "Unknown Auth State"
    case unauthenticated = "Not Authenticated"
    case authenticated = "Authenticated"
}

class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .unknown
    @Published var authError: String? = nil

    @Published var showAlert = false
    @Published var alertMessage: String = ""

    @AppStorage("currentUserID") private var currentUserID: String?
    @AppStorage("currentUserEmail") private var currentUserEmail: String?
    @AppStorage("currentUserFullName") private var currentUserFullName: String?
    @AppStorage("sessionToken") private var sessionToken: String?

    /// Sets authState according to backend's response to sessionToken
    func tryLogin() async {
        guard let token = sessionToken, !token.isEmpty else {
            authState = .unauthenticated
            return
        }

        do {
            let response = try await AuthService.shared
                .letBackendValidateSessionToken()
            if response.statusCode == 401 {
                authState = .unauthenticated
            }
            authState = .authenticated
        } catch {
            alertMessage = "ERROR authenticating: " + error.localizedDescription
            showAlert = true

            authState = .unauthenticated
        }
    }

    func logout() {
        currentUserID = nil
        currentUserEmail = nil
        currentUserFullName = nil

        sessionToken = ""

        authState = .unauthenticated
    }
}

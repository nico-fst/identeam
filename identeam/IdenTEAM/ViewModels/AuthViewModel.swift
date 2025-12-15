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
    case unknown = "Unknown"
    case unauthenticated = "Not Authed"
    case authenticated = "Authed"
}

class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .unknown
    @Published var authError: String? = nil

    @Published var showAlert = false
    @Published var alertMessage: String = ""

    @AppStorage("sessionToken") private var sessionToken: String?

    /// Sets authState according to backend's response to sessionToken
    func tryLogin() async throws {
        let isValid = try await AuthService.shared
            .letBackendValidateSessionToken()

        authState = isValid ? .authenticated : .unauthenticated
    }

    func logout() {
        authState = .unauthenticated
        sessionToken = ""
    }
}

//
//  AuthService.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Foundation
import SwiftUI

enum AuthError: LocalizedError {
    case unexpectedAnswer
    case emptySessionToken
    case emailOrPasswordMissing
    case fullNameOrUsernameMissing
    case userNotFound
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedAnswer:
            return "Unexpected response from backend"
        case .emptySessionToken:
            return "Empty session token while trying to auth against backend"
        case .emailOrPasswordMissing:
            return "Email and Password are required"
        case .fullNameOrUsernameMissing:
            return "Full Name and Username are required"
        case .userNotFound:
            return "User not found"
        case .backend(let message):
            return message
        }
    }
}

struct AuthResponse: Decodable {
    let user: User
    let sessionToken: String
    let created: Bool  // == new user was creted in backend
}

class AuthService {
    @AppStorage("sessionToken") private var sessionToken: String = ""

    static let shared = AuthService()

    /// Exchanges identityToken and authorizationCode for sessionToken
    /// - Returns: custom JWT sessionToken valid for 30d
    func sendAuthFlowToBackend(
        identityToken: String,
        authorizationCode: String,
        user: User
    ) async throws -> AuthResponse {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "auth/apple/native/callback"
        )

        let payload: [String: Any] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode,
            "userID": user.userID,
            "fullName": user.fullName,
        ]

        let response: BackendResponse<AuthResponse> =
            try await RequestService.shared.postToBackend(
                url: url,
                payload: payload
            )

        return response.data!
    }

    /// Let backend validate the sessionToken in UserDefaults send as Bearer
    /// - Returns: if backend accepts sessionToken
    func letBackendValidateSessionToken() async throws -> BackendResponse<Empty>
    {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "auth/apple/check_session"
        )

        guard !sessionToken.isEmpty else {
            throw AuthError.emptySessionToken
        }

        let response: BackendResponse<Empty> = try await RequestService.shared
            .getToBackend(url: url)

        return response
    }
    
    func sendPasswordFlowToBackend(
            authMode: AuthMode,
            email: String, password: String
    ) async throws -> AuthResponse {
        let endpoint = authMode == .signup ? "auth/password/signup" : "auth/password/login"
        let url = AppConfig.apiBaseURL.appendingPathComponent(endpoint)
        print(url.absoluteString)
        
        let payload: [String: Any] = [
            "email": email,
            "password": password,
        ]
        
        do {
            let response: BackendResponse<AuthResponse> =
                try await RequestService.shared.postToBackend(
                    url: url,
                    payload: payload
                )

            if response.statusCode == 404 { // user does not exist => signup instead
                throw AuthError.userNotFound
            }
            
            guard let data = response.data else {
                throw AuthError.backend(response.message)
            }
            
            return data
        } catch {
            throw error
        }
    }
}


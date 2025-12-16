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

    var errorDescription: String? {
        switch self {
        case .unexpectedAnswer:
            return "Unexpected response from backend"
        case .emptySessionToken:
            return "Empty session token while trying to auth against backend"
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
}

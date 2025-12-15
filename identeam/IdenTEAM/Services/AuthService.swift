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

    var errorDescription: String? {
        switch self {
        case .unexpectedAnswer:
            return "Unexpected response from backend"
        }
    }
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
    ) async throws -> String {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "auth/apple/native/callback"
        )

        let payload: [String: Any] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode,
            "userID": user.userID,
            "fullName": user.fullName,
        ]

        let response = try await RequestService.shared.postToBackend(
            url: url,
            payload: payload
        )

        if let data = response.data {
            return data["sessionToken"] as! String
        } else {
            throw AuthError.unexpectedAnswer
        }
    }

    /// Let backend validate the sessionToken in UserDefaults send as Bearer
    /// - Returns: if backend accepts sessionToken
    func letBackendValidateSessionToken() async throws
        -> Bool
    {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "auth/apple/check_session"
        )

        let response = try await RequestService.shared.getToBackend(url: url)

        return response.statusCode == 200
    }
}

//
//  TokenService.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Foundation
import SwiftUI

enum TokenError: LocalizedError {
    case missingDeviceToken

    var errorDescription: String? {
        switch self {
        case .missingDeviceToken:
            return "No Device Token while sending it to backend bruh"
        }
    }
}

class TokenService {
    @AppStorage("deviceToken") private var deviceToken: String?

    static let shared = TokenService()

    /// tries propagating current deviceToken to backend
    func sendDeviceTokenToBackend() async throws {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "token/update_device_token"
        )

        guard let deviceToken else { throw TokenError.missingDeviceToken }

        let payload: [String: Any] = [
            "newToken": deviceToken,
            "platform": "ios",  // TODO make dynamic if planning to extend to other OS
        ]

        let _: BackendResponse<User> = try await RequestService.shared
            .postToBackend(
                url: url,
                payload: payload
            )
    }
}

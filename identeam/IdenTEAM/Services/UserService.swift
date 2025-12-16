//
//  UserService.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Foundation
import SwiftUI

enum UserError: LocalizedError {
    case missingPayload

    var errorDescription: String? {
        switch self {
        case .missingPayload:
            return
                "missing payload: needs userID, email, fullName, username in UserDefaults"
        }
    }
}

class UserService {
    static let shared = UserService()

    @AppStorage("userID") private var userID: String?
    @AppStorage("email") private var email: String?

    // TODO extend to email being editable
    func requestUserDetailsChange(fullName: String, username: String)
        async throws -> User
    {
        let url = AppConfig.apiBaseURL.appendingPathComponent("me/update_user")

        guard let userID, let email else {
            throw UserError.missingPayload
        }

        let payload: [String: Any] = [
            "user": [
                "userID": userID,
                "email": email,
                "fullName": fullName,
                "username": username,
            ]
        ]

        let response: BackendResponse<User> = try await RequestService.shared
            .postToBackend(url: url, payload: payload)

        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw NSError(
                domain: "",
                code: response.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: response.message
                ]
            )
        }
    }
}

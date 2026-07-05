//
//  CommentAPI.swift
//  identeam
//
//  Created by Nico Stern on 05.07.26.
//

import Foundation

class CommentAPI {
    static let shared = CommentAPI()
    
    func comment(text: String, slug: String, identID: Int) async throws -> CommentDTO {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "/teams/\(slug)/idents/\(identID)/comment"
        )
        let payload: [String: Any] = [
            "text": text
        ]

        let response: BackendResponse<CommentDTO> =
            try await API.shared.postToBackend(
                url: url,
                payload: payload
            )

        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw TeamError.backend(response.message)
        }
    }
}

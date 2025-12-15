//
//  RequestService.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Foundation
import SwiftUI

struct BackendResponse {
    let statusCode: Int
    let rawData: Data?
    // JSONResponse: { error, message, data }
    let error: Bool
    let message: String
    let data: [String: Any]?

}

class RequestService {
    @AppStorage("sessionToken") private var sessionToken: String?

    static let shared = RequestService()

    func postToBackend(url: URL, payload: [String: Any]) async throws
        -> BackendResponse
    {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10  // in seconds
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Bearer \(sessionToken ?? "")",
            forHTTPHeaderField: "Authorization"
        )

        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: payload
            )
        } catch {
            print("ERROR serializing JSON:", error)
            throw error
        }

        let (data, response) = try await URLSession.shared.data(
            for: request
        )
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        var json: [String: Any]? = nil
        if !data.isEmpty {
            json =
                try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        }

        return BackendResponse(
            statusCode: statusCode,
            rawData: data,
            error: json?["error"] as? Bool ?? false,
            message: json?["message"] as? String ?? "",
            data: json?["data"] as? [String: Any]
        )
    }

    func getToBackend(url: URL) async throws -> BackendResponse {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10  // in seconds
        request.httpMethod = "GET"
        request.setValue(
            "Bearer \(sessionToken ?? "")",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        var json: [String: Any]? = nil
        if !data.isEmpty {
            json =
                try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        }

        return BackendResponse(
            statusCode: statusCode,
            rawData: data,
            error: json?["error"] as? Bool ?? false,
            message: json?["message"] as? String ?? "",
            data: json?["data"] as? [String: Any]
        )
    }
}

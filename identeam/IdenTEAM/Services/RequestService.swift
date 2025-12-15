//
//  RequestService.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Foundation
import SwiftUI

struct BackendResponse<T: Decodable> {
    let statusCode: Int
    let rawData: Data?
    // JSONResponse: { error, message, data }
    let error: Bool
    let message: String
    let data: T?

}

enum RequestServiceError: Error {
    case decodingDataFailed(reason: String)
}

class RequestService {
    @AppStorage("sessionToken") private var sessionToken: String?

    static let shared = RequestService()

    func postToBackend<T: Decodable>(
        url: URL,
        payload: [String: Any],
    ) async throws
        -> BackendResponse<T>
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

        print("POST \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(
            for: request
        )
        print("---> \(String(data: data, encoding: .utf8))")

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            throw URLError(.badServerResponse)
        }

        // try decoding json
        let json =
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let error = json?["error"] as? Bool ?? false
        let message = json?["message"] as? String ?? ""

        var decoded: T? = nil
        if let dataObject = json?["data"] {
            let dataJSON = try JSONSerialization.data(
                withJSONObject: dataObject
            )
            decoded = try JSONDecoder().decode(T.self, from: dataJSON)
        }

        return BackendResponse(
            statusCode: statusCode,
            rawData: data,
            error: error,
            message: message,
            data: decoded  // T?
        )
    }

    func getToBackend<T: Decodable>(url: URL) async throws -> BackendResponse<T>
    {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10  // in seconds
        request.httpMethod = "GET"
        request.setValue(
            "Bearer \(sessionToken ?? "")",
            forHTTPHeaderField: "Authorization"
        )

        print("GET \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(
            for: request
        )
        print("---> \(String(data: data, encoding: .utf8))")

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            throw URLError(.badServerResponse)
        }

        // try decoding json
        let json =
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let error = json?["error"] as? Bool ?? false
        let message = json?["message"] as? String ?? ""

        var decoded: T? = nil
        if let dataObject = json?["data"] {
            let dataJSON = try JSONSerialization.data(
                withJSONObject: dataObject
            )
            decoded = try JSONDecoder().decode(T.self, from: dataJSON)
        }

        return BackendResponse(
            statusCode: statusCode,
            rawData: data,
            error: error,
            message: message,
            data: decoded  // T?
        )
    }
}

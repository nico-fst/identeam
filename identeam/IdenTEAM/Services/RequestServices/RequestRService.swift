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

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

class RequestRService {
    @AppStorage("sessionToken") private var sessionToken: String?

    static let shared = RequestRService()
    
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func sendToBackend<T: Decodable>(
        url: URL,
        method: HTTPMethod,
        payload: [String: Any]? = nil,
    ) async throws
        -> BackendResponse<T>
    {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if method == .post || method == .put {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = sessionToken, !token.isEmpty {
            request.setValue(
                "Bearer \(sessionToken ?? "")",
                forHTTPHeaderField: "Authorization"
            )
        }

        if let payload {
            do {
                request.httpBody = try JSONSerialization.data(
                    withJSONObject: payload
                )
            } catch {
                print("ERROR serializing JSON:", error)
                throw error
            }
        }

        print("\(method.rawValue) \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(
            for: request
        )
        print("---> \(String(describing: String(data: data, encoding: .utf8)))")

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        // try decoding json
        let json =
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let error = json?["error"] as? Bool ?? false
        let message = json?["message"] as? String ?? ""

        var decoded: T? = nil
        if (200...299).contains(statusCode) {  // only OKs have body
            if let dataObject = json?["data"] {
                let dataJSON = try JSONSerialization.data(
                    withJSONObject: dataObject
                )
                decoded = try decoder.decode(T.self, from: dataJSON)
            }
        } else if statusCode == 401 {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .didReceiveUnauthorized,
                    object: nil
                )
            }
        }

        return BackendResponse(
            statusCode: statusCode,
            rawData: data,
            error: error,
            message: message,
            data: decoded  // T?
        )
    }

    func postToBackend<T: Decodable>(
        url: URL,
        payload: [String: Any]? = nil,
    ) async throws -> BackendResponse<T> {
        try await sendToBackend(
            url: url,
            method: .post,
            payload: payload
        )
    }

    func putToBackend<T: Decodable>(
        url: URL,
        payload: [String: Any]? = nil,
    ) async throws -> BackendResponse<T> {
        try await sendToBackend(
            url: url,
            method: .put,
            payload: payload
        )
    }

    func getToBackend<T: Decodable>(url: URL) async throws -> BackendResponse<T> {
        try await sendToBackend(
            url: url,
            method: .get
        )
    }
}

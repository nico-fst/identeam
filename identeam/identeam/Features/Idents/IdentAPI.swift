//
//  IdentAPI.swift
//  identeam
//
//  Created by Nico Stern on 13.05.26.
//

import Foundation

class IdentAPI {
    static let shared = IdentAPI()
    
    func createIdent(slug: String, text: String) async throws -> IdentDTO {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "/teams/\(slug)/idents/create"
        )
        
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "time": formatter.string(from: Date()),
            "userText": text
        ]

        let response: BackendResponse<IdentDTO> =
            try await API.shared.postToBackend(url: url, payload: payload)

        switch response.statusCode {
        case 200:
            return response.data!
        case 404:
            throw TeamError.targetNotSet
        default:
            throw TeamError.backend(response.message)
        }
    }
    
    func getIdentImageUploadURL(slug: String, identID: String, contentType: String, sizeBytes: Int) async throws -> PresignedDTO {
        let url = AppConfig.apiBaseURL.appendingPathComponent("/teams/\(slug)/idents/\(identID)/image/get_upload_url")
        let payload: [String: Any] = [
            "contentType": contentType,
            "sizeBytes": sizeBytes
        ]
        
        let response: BackendResponse<PresignedDTO> = try await API.shared.postToBackend(url: url, payload: payload)
        
        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw APIError.backend(response.message)
        }
    }

    func commitIdentImageUpload(key: String, slug: String, identID: String) async throws -> CommitS3DTO {
        let url = AppConfig.apiBaseURL.appendingPathComponent("/teams/\(slug)/idents/\(identID)/image/commit")
        let payload: [String: Any] = [
            "key": key
        ]
        
        let response: BackendResponse<CommitS3DTO> = try await API.shared.postToBackend(url: url, payload: payload)
        
        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw APIError.backend(response.message)
        }
    }
    
    func storeIdentImage(slug: String, identID: String, imageData: Data, contentType: String) async throws {
        try await S3UploadAPI.upload(
            imageData: imageData,
            contentType: contentType,
            getUploadURL: { [self] contentType, sizeBytes in
                try await getIdentImageUploadURL(
                    slug: slug,
                    identID: identID,
                    contentType: contentType,
                    sizeBytes: sizeBytes
                )
            },
            commit: { [self] key in
                try await commitIdentImageUpload(key: key, slug: slug, identID: identID)
            }
        )
    }
}

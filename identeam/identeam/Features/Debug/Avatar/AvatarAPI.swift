import Foundation

class AvatarAPI {
    static let shared = AvatarAPI()
    
    struct GetMeResponse: Decodable {
        let user: UserDTO
    }

    func fetchMe() async throws -> GetMeResponse {
        let url = AppConfig.apiBaseURL.appendingPathComponent("me")
        
        let response: BackendResponse<GetMeResponse> = try await API.shared.getToBackend(url: url)
        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw APIError.backend(response.message)
        }
    }

    private func getAvatarUploadURL(contentType: String, sizeBytes: Int) async throws -> PresignedDTO {
        let url = AppConfig.apiBaseURL.appendingPathComponent("me/avatar/get_upload_url")
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

    private func commitAvatarUpload(key: String) async throws -> CommitS3DTO {
        let url = AppConfig.apiBaseURL.appendingPathComponent("me/avatar/commit")
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

    func uploadAvatar(imageData: Data, contentType: String) async throws {
        try await S3UploadAPI.upload(
            imageData: imageData,
            contentType: contentType,
            getUploadURL: { [self] contentType, sizeBytes in
                try await getAvatarUploadURL(contentType: contentType, sizeBytes: sizeBytes)
            },
            commit: { [self] key in
                try await commitAvatarUpload(key: key)
            }
        )
    }
}

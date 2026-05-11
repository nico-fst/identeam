import Foundation

class AvatarAPI {
    static let shared = AvatarAPI()
    
    struct GetMeResponse: Decodable {
        let user: UserDTO
        let avatar: PresignedDTO?
    }

    struct CommitAvatarResponse: Decodable {
        let key: String
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

    func getAvatarUploadURL(contentType: String, sizeBytes: Int) async throws -> PresignedDTO {
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

    func uploadAvatarData(_ data: Data, to uploadURL: URL, contentType: String) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func commitAvatarUpload(key: String) async throws -> CommitAvatarResponse {
        let url = AppConfig.apiBaseURL.appendingPathComponent("me/avatar/commit")
        let payload: [String: Any] = [
            "key": key
        ]
        
        let response: BackendResponse<CommitAvatarResponse> = try await API.shared.postToBackend(url: url, payload: payload)
        
        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw APIError.backend(response.message)
        }
    }

    func uploadAvatar(imageData: Data, contentType: String) async throws {
        let uploadInfo = try await getAvatarUploadURL(
            contentType: contentType,
            sizeBytes: imageData.count
        )
        guard let uploadURL = URL(string: uploadInfo.presignedURL) else {
            throw URLError(.badURL)
        }

        try await uploadAvatarData(imageData, to: uploadURL, contentType: contentType)
        _ = try await commitAvatarUpload(key: uploadInfo.key)
    }
}

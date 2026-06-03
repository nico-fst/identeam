import Foundation

struct CommitS3DTO: Decodable {
    let key: String
}

enum S3UploadAPI {
    private static func uploadData(_ data: Data, to uploadURL: URL, contentType: String) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(for: request, from: data)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static func upload(
        imageData: Data,
        contentType: String,
        getUploadURL: (String, Int) async throws -> PresignedDTO,
        commit: (String) async throws -> CommitS3DTO
    ) async throws {
        let uploadInfo = try await getUploadURL(contentType, imageData.count)
        guard let uploadURL = URL(string: uploadInfo.presignedURL) else {
            throw URLError(.badURL)
        }

        try await uploadData(imageData, to: uploadURL, contentType: contentType)
        _ = try await commit(uploadInfo.key)
    }
}

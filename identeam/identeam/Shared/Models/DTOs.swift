import Foundation

struct Empty: Decodable {}

struct PresignedDTO: Decodable {
    let key: String
    let presignedURL: String
    let expiresAt: Date
}

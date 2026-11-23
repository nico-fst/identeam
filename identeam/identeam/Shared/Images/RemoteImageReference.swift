import Foundation

/// A stable cache key and a temporary download URL, independent of persistence.
nonisolated struct RemoteImageReference: Codable, Equatable, Sendable {
    let key: String
    let url: URL
    let expiresAt: Date
}

extension RemoteImageReference {
    @MainActor
    init(item: S3Item) {
        self.init(key: item.key, url: item.url, expiresAt: item.expiresAt)
    }
}

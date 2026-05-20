//
//  Avatar.swift
//  identeam
//
//  Created by Nico Stern on 09.05.26.
//

import Foundation
import SwiftData

enum ImageKind: String, Codable {
    case avatar
    case identImage
}

@Model
final class S3Item {
    var url: URL
    var key: String
    var expiresAt: Date
    var kindRaw: String
    
    var isExpired: Bool {
        expiresAt <= Date()
    }
    
    var kind: ImageKind {
        get { ImageKind(rawValue: kindRaw) ?? .avatar }
        set { kindRaw = newValue.rawValue }
    }
    
    var owner: String? {
        switch kind {
        case .avatar:
            let parts = key.split(separator: "/")
            guard parts.count >= 2 else {
                return nil
            }
            
            return String(parts[1])
        case .identImage:
            return nil
        }
    }
    
    init(
        url: URL,
        key: String,
        expiresAt: Date,
        kind: ImageKind
    ) {
        self.url = url
        self.key = key
        self.expiresAt = expiresAt
        self.kindRaw = kind.rawValue
    }
    
    convenience init(dto: PresignedDTO, kind: ImageKind) {
        self.init(
            url: URL(string: dto.presignedURL)!,
            key: dto.key,
            expiresAt: dto.expiresAt,
            kind: kind
        )
    }
}

//
//  Avatar.swift
//  identeam
//
//  Created by Nico Stern on 09.05.26.
//

import Foundation
import SwiftData

enum S3ItemKind: String, Codable {
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
    
    var kind: S3ItemKind {
        get { S3ItemKind(rawValue: kindRaw) ?? .avatar }
        set { kindRaw = newValue.rawValue }
    }
    
    var ownerID: String? {
        let parts = key.split(separator: "/")
        
        switch kind {
        case .avatar:
            guard parts.count == 4 else {
                return nil
            }
            return String(parts[1])
        case .identImage:
            guard parts.count == 5  else {
                return nil
            }
            return String(parts[3])
        }
    }
    
    init(
        url: URL,
        key: String,
        expiresAt: Date,
        kind: S3ItemKind
    ) {
        self.url = url
        self.key = key
        self.expiresAt = expiresAt
        self.kindRaw = kind.rawValue
    }
    
    convenience init(dto: PresignedDTO, kind: S3ItemKind) {
        self.init(
            url: URL(string: dto.presignedURL)!,
            key: dto.key,
            expiresAt: dto.expiresAt,
            kind: kind
        )
    }
}

extension S3Item {
    static var templatePicsum1: S3Item {
        S3Item(
            url: URL(string: "https://picsum.photos/200/300")!,
            key: "teams/slug_here/idents/ident_id/image_vX.png",
            expiresAt: Date().addingTimeInterval(60),
            kind: .identImage
        )
    }
    
    static var templatePicsum2: S3Item {
        S3Item(
            url: URL(string: "https://picsum.photos/200")!,
            key: "teams/another_slug/idents/another_ident_id/image_vX.png",
            expiresAt: Date().addingTimeInterval(60),
            kind: .identImage
        )
    }
    
    static var templatePicsum3: S3Item {
        S3Item(
            url: URL(string: "https://picsum.photos/250")!,
            key: "teams/even_another_slug/idents/even_another_ident_id/image_vX.png",
            expiresAt: Date().addingTimeInterval(60),
            kind: .identImage
        )
    }
}

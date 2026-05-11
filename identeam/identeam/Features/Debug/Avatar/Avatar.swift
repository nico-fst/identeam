//
//  Avatar.swift
//  identeam
//
//  Created by Nico Stern on 09.05.26.
//

import Foundation
import SwiftData

@Model
final class Avatar {
    var url: URL
    var key: String
    var expiresAt: Date
    
    var isExpired: Bool {
        expiresAt <= Date()
    }
    
    init(
        url: URL,
        key: String,
        expiresAt: Date
    ) {
        self.url = url
        self.key = key
        self.expiresAt = expiresAt
    }
    
    convenience init(dto: PresignedDTO) {
        self.init(
            url: URL(string: dto.presignedURL)!,
            key: dto.key,
            expiresAt: dto.expiresAt
        )
    }
}

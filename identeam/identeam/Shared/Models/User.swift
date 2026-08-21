//
//  User.swift
//  identeam
//
//  Created by Nico Stern on 15.03.26.
//

import Foundation
import SwiftData

struct UserDTO: Decodable {
    let userID: String
    let email: String
    let nickname: String
    let username: String
    let avatar: PresignedDTO?
}

@Model
final class User {
    var userID: String
    var email: String
    @Attribute(originalName: "fullName")
    var nickname: String
    var username: String
    var avatar: S3Item
    
    init(
        userID: String,
        email: String,
        nickname: String,
        username: String,
        avatar: S3Item
    ) {
        self.userID = userID
        self.email = email
        self.nickname = nickname
        self.username = username
        self.avatar = avatar
    }
    
    convenience init(dto: UserDTO) {
        self.init(
            userID: dto.userID,
            email: dto.email,
            nickname: dto.nickname,
            username: dto.username,
            avatar: S3Item.avatar(for: dto)
        )
    }
}

extension User {
    static var templateGreta: User {
        User(
            userID: "abc",
            email: "gre@ta.de",
            nickname: "Greta Kante",
            username: "greta-kante",
            avatar: .templatePicsum2
        )
    }
    
    static var templateNico: User {
        User(
            userID: "xyz",
            email: "ni@co.de",
            nickname: "Nico Kante",
            username: "nico-kante",
            avatar: .templatePicsum3
        )
    }
}

enum DiceBear {
    static func avatarURL(seed: String) -> URL {
        var components = URLComponents(string: "https://api.dicebear.com/10.x/adventurer/jpg")!
        components.queryItems = [
            URLQueryItem(name: "seed", value: seed),
            URLQueryItem(
                name: "backgroundColor",
                value: [
                    "cbf0ff", "d3e2ff", "d9c9fe", "efcaff", "f9d3e0", "ffdbd8", "ffe2d6", "ffecd4", "fff2d5", "fefcdd", "f7fadb", "dfeed4"
                ].joined(separator: ",")
            )
        ]
        
        return components.url!
    }
}

extension S3Item {
    static func avatar(
        for dto: UserDTO,
        kind: S3ItemKind = .avatar
    ) -> S3Item {
        if let dtoAvatar = dto.avatar {
            return S3Item(dto: dtoAvatar, kind: kind)
        }

        return S3Item(
            url: DiceBear.avatarURL(seed: dto.username),
            key: "dicebear-\(dto.username)",
            expiresAt: Date().addingTimeInterval(60 * 10),
            kind: kind
        )
    }
}

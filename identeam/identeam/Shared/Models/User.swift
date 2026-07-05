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
    let avatar: PresignedDTO
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
            avatar: S3Item(dto: dto.avatar, kind: .avatar)
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


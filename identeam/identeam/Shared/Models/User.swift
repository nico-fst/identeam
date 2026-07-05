//
//  User.swift
//  identeam
//
//  Created by Nico Stern on 15.03.26.
//

import Foundation
import SwiftData

struct UserDTO: Codable {
    let userID: String
    let email: String
    let nickname: String
    let username: String
}

@Model
final class User {
    var userID: String
    var email: String
    @Attribute(originalName: "fullName")
    var nickname: String
    var username: String
    
    init(
        userID: String,
        email: String,
        nickname: String,
        username: String,
    ) {
        self.userID = userID
        self.email = email
        self.nickname = nickname
        self.username = username
    }
    
    convenience init(dto: UserDTO) {
        self.init(
            userID: dto.userID,
            email: dto.email,
            nickname: dto.nickname,
            username: dto.username,
        )
    }
}

extension User {
    static var templateGreta: User {
        User(
            userID: "abc",
            email: "gre@ta.de",
            nickname: "Greta Kante",
            username: "greta-kante")
    }
    
    static var templateNico: User {
        User(
            userID: "xyz",
            email: "ni@co.de",
            nickname: "Nico Kante",
            username: "nico-kante")
    }
}

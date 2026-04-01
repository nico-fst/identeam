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
    let fullName: String
    let username: String
}

@Model
final class User {
    var userID: String
    var email: String
    var fullName: String
    var username: String
    
    init(
        userID: String,
        email: String,
        fullName: String,
        username: String
    ) {
        self.userID = userID
        self.email = email
        self.fullName = fullName
        self.username = username
    }
    
    convenience init(dto: UserDTO) {
        self.init(
            userID: dto.userID,
            email: dto.email,
            fullName: dto.fullName,
            username: dto.username
        )
    }
}


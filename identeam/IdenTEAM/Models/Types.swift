//
//  AuthState.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Foundation

struct User: Codable {
    var userID: String
    var email: String
    var fullName: String
    var username: String
}

struct Empty: Decodable {}

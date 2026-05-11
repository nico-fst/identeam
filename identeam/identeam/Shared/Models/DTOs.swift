//
//  AuthState.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Foundation

struct Empty: Decodable {}

struct PresignedDTO: Decodable {
    let key: String
    let presignedURL: String
    let expiresAt: Date
}

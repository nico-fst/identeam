//
//  Ident.swift
//  identeam
//
//  Created by Nico Stern on 13.03.26.
//

import Foundation
import SwiftData

struct IdentDTO: Decodable {
    let id: Int
    let time: Date
    let userText: String
}

@Model
final class Ident {
    var remoteID: Int
    var time: Date
    var userText: String
    
    init(
        remoteID: Int = 0,
        time: Date,
        userText: String
    ) {
        self.remoteID = remoteID
        self.time = time
        self.userText = userText
    }
    
    convenience init(dto: IdentDTO) {
        self.init(
            remoteID: dto.id,
            time: dto.time,
            userText: dto.userText
        )
    }
}

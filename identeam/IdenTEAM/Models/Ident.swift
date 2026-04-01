//
//  Ident.swift
//  identeam
//
//  Created by Nico Stern on 13.03.26.
//

import Foundation
import SwiftData

struct IdentDTO: Decodable {
    let time: Date
    let userText: String
}

@Model
final class Ident {
    var time: Date
    var userText: String
    
    init(
        time: Date,
        userText: String
    ) {
        self.time = time
        self.userText = userText
    }
    
    convenience init(dto: IdentDTO) {
        self.init(
            time: dto.time,
            userText: dto.userText
        )
    }
}

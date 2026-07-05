//
//  Comment.swift
//  identeam
//
//  Created by Nico Stern on 05.07.26.
//

import Foundation
import SwiftData

struct CommentDTO: Decodable {
    let id: Int
    let time: Date
    let text: String
    let user: UserDTO
}

@Model
final class Comment {
    var id: Int
    var time: Date
    var text: String
    var user: User
    
    init(
        id: Int = 0,
        time: Date,
        text: String,
        user: User
    ) {
        self.id = id
        self.time = time
        self.text = text
        self.user = user
    }
    
    convenience init(dto: CommentDTO) {
        self.init(
            id: dto.id,
            time: dto.time,
            text: dto.text,
            user: User(dto: dto.user)
        )
    }
}

extension Comment {
    static var templateWow: Comment {
        Comment(time: Date(), text: "Wow that's so cool", user: .templateGreta)
    }
    
    static var templateGood: Comment {
        Comment(time: Date(), text: "Good job!", user: .templateGreta)
    }
    
    static var templateSiuu: Comment {
        Comment(time: Date(), text: "Siuu", user: .templateNico)
    }
}

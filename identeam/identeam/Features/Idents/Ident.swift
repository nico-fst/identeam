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
    let image: PresignedDTO
    let comments: [CommentDTO]
}

@Model
final class Ident {
    var remoteID: Int
    var time: Date
    var userText: String
    var image: S3Item
    var comments: [Comment]
    
    init(
        remoteID: Int = 0,
        time: Date,
        userText: String,
        image: S3Item,
        comments: [Comment]
    ) {
        self.remoteID = remoteID
        self.time = time
        self.userText = userText
        self.image = image
        self.comments = comments
    }
    
    convenience init(dto: IdentDTO) {
        self.init(
            remoteID: dto.id,
            time: dto.time,
            userText: dto.userText,
            image: S3Item(dto: dto.image, kind: S3ItemKind.identImage),
            comments: dto.comments.map { Comment(dto: $0) }
        )
    }
}

extension Ident {
    static var templateGym: Ident {
        Ident(
            time: Date(),
            userText: "Ich war grad im Gym",
            image: .templateIdentImage,
            comments: [.templateSiuu]
        )
    }
    
    static var templateOtherGym: Ident {
        Ident(
            time: Date(),
            userText: "Ich war auch grad im Gym",
            image: .templateIdentImage,
            comments: [.templateWow, .templateGood]
        )
    }
    
    static var templateEvenOtherGym: Ident {
        Ident(
            time: Date(),
            userText: "Und auch ich war auch grad im Gym",
            image: .templateIdentImage,
            comments: [.templateWow, .templateSiuu]
        )
    }
    
    static var templatePiano: Ident {
        Ident(
            time: Date(),
            userText: "Ich hab grad Piano gespielt",
            image: .templateIdentImage,
            comments: [.templateWow, .templateSiuu, .templateGood]
        )
    }
}

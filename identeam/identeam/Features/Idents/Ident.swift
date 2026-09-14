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
            image: S3Item(dto: dto.image, kind: .identImage),
            comments: dto.comments.map { Comment(dto: $0) }
        )
    }
}

extension Ident {
    static var templateGym: Ident {
        Ident(
            remoteID: 1,
            time: Date(),
            userText: "Ich war grad im Gym",
            image: .templatePicsum1,
            comments: [.templateSiuu, .templateWow]
        )
    }
    
    static var templateOtherGym: Ident {
        Ident(
            remoteID: 2,
            time: Date(),
            userText: "Ich war auch grad im Gym und dieser Text hier ist sehr lang",
            image: .templatePicsum1,
            comments: [.templateWow, .templateGood]
        )
    }
    
    static var templateEvenOtherGym: Ident {
        Ident(
            remoteID: 3,
            time: Date(),
            userText: "Und auch ich war auch grad im Gym und dieser Text ist äußerst lang",
            image: .templatePicsum1,
            comments: [.templateWow, .templateSiuu]
        )
    }
    
    static var templatePiano: Ident {
        Ident(
            remoteID: 4,
            time: Date(),
            userText: "Ich hab grad Piano gespielt",
            image: .templatePicsum1,
            comments: [.templateWow, .templateSiuu, .templateGood]
        )
    }
}

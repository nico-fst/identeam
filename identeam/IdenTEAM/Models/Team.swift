//
//  Models.swift
//  identeam
//
//  Created by Nico Stern on 28.12.25.
//

import Foundation
import SwiftData

@Model
final class Team {
    var slug: String
    var name: String
    var details: String

    init(
        name: String,
        slug: String,
        details: String
    ) {
        self.name = name
        self.slug = slug
        self.details = details
    }
}

// since @Model und :Decodable don't work together
struct TeamDecodable: Decodable {
    let slug: String
    let name: String
    let details: String
}

extension Team {
    convenience init(dto: TeamDecodable) {
        self.init(
            name: dto.name,
            slug: dto.slug,
            details: dto.details
        )
    }

    static func fromDTOs(_ dtos: [TeamDecodable]) -> [Team] {
        dtos.map { Team(dto: $0) }
    }
}


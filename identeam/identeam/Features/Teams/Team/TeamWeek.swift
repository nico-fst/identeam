//
//  TeamWeek.swift
//  identeam
//
//  Created by Nico Stern on 15.03.26.
//

import Foundation
import SwiftData

struct TeamMemberDTO: Decodable {
    let user: UserDTO
    let targetCount: UInt
    let idents: [IdentDTO]
}

@Model
final class TeamMember: Identifiable {
    var id = UUID()
    var user: User
    var targetCount: UInt
    var idents: [Ident]
    
    init(
        user: User,
        targetCount: UInt,
        idents: [Ident]
    ) {
        self.user = user
        self.targetCount = targetCount
        self.idents = idents
    }
    
    convenience init(dto: TeamMemberDTO) {
        self.init(
            user: User(dto: dto.user),
            targetCount: dto.targetCount,
            idents: dto.idents.map { Ident(dto: $0) }
        )
    }
}

struct TeamWeekDTO: Decodable {
    let slug: String
    let targetSum: UInt
    let identSum: UInt
    let members: [TeamMemberDTO]
}

@Model final class TeamWeek {
    var slug: String
    var targetSum: UInt
    var identSum: UInt
    var members: [TeamMember]
    
    init(
        slug: String,
        targetSum: UInt,
        identSum: UInt,
        members: [TeamMember]
    ) {
        self.slug = slug
        self.targetSum = targetSum
        self.identSum = identSum
        self.members = members
    }
    
    convenience init(dto: TeamWeekDTO) {
        self.init(
            slug: dto.slug,
            targetSum: dto.targetSum,
            identSum: dto.identSum,
            members: dto.members.map { TeamMember(dto: $0) }
        )
    }
}

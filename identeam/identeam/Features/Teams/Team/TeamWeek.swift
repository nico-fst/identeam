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
    let targetDays: [String]
    let idents: [IdentDTO]
}

@Model
final class TeamMember: Identifiable {
    var id = UUID()
    var user: User
    var targetDays: [Date]
    var idents: [Ident]
    
    init(
        user: User,
        targetDays: [String],
        idents: [Ident]
    ) {
        self.user = user
        
        self.targetDays = targetDays.compactMap(ReminderSchedulePlanner.parseDate)
        self.idents = idents
    }
    
    convenience init(dto: TeamMemberDTO) {
        self.init(
            user: User(dto: dto.user),
            targetDays: dto.targetDays,
            idents: dto.idents.map { Ident(dto: $0) }
        )
    }
}

extension TeamMember {
    static var templateGretaKanten: TeamMember {
        TeamMember(
            user: .templateGreta,
            targetDays: ["2026-02-02", "2026-02-03", "2026-02-04"],
            idents: [
                .templateGym,
                .templateOtherGym,
            ]
        )
    }
    
    static var templateNicoKanten: TeamMember {
        TeamMember(
            user: .templateNico,
            targetDays: ["2026-02-02", "2026-02-04"],
            idents: [
                .templateEvenOtherGym,
            ]
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

extension TeamWeek {
    static var templateKanten: TeamWeek {
        TeamWeek(
            slug: "die-kanten",
            targetSum: 6,
            identSum: 3,
            members: [
                .templateGretaKanten,
                .templateNicoKanten
            ]
        )
    }
}

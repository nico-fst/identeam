import Foundation
import SwiftData

struct TeamWeekDTO: Decodable {
    let slug: String
    let targetSum: UInt
    let identSum: UInt
    let members: [TeamMemberDTO]
    let teamStreak: UInt
}

@Model final class TeamWeek {
    var slug: String
    var targetSum: UInt
    var identSum: UInt
    var members: [TeamMember]
    var teamStreak: UInt

    init(
        slug: String,
        targetSum: UInt,
        identSum: UInt,
        members: [TeamMember],
        teamStreak: UInt
    ) {
        self.slug = slug
        self.targetSum = targetSum
        self.identSum = identSum
        self.members = members
        self.teamStreak = teamStreak
    }

    convenience init(dto: TeamWeekDTO) {
        self.init(
            slug: dto.slug,
            targetSum: dto.targetSum,
            identSum: dto.identSum,
            members: dto.members.map { TeamMember(dto: $0) },
            teamStreak: dto.teamStreak
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
            ],
            teamStreak: 2
        )
    }
    
    static var templateBadKanten: TeamWeek {
        TeamWeek(
            slug: "die-kanten",
            targetSum: 6,
            identSum: 1,
            members: [
                .templateGretaKanten,
                .templateNicoKanten
            ],
            teamStreak: 0
        )
    }
    
    static var templateGoodkanten: TeamWeek {
        TeamWeek(
            slug: "die-kanten",
            targetSum: 6,
            identSum: 7,
            members: [
                .templateGretaKanten,
                .templateNicoKanten
            ],
            teamStreak: 9
        )
    }
}

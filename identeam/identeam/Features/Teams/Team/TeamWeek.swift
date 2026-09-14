import Foundation
import SwiftData

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

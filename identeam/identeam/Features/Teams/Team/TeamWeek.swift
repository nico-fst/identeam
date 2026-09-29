import Foundation
import SwiftData

struct TeamWeekDTO: Decodable {
    let slug: String
    let weekStart: Date
    let targetSum: UInt
    let identSum: UInt
    let members: [TeamMemberDTO]
    let teamStreak: UInt
}

@Model final class TeamWeek {
    #Unique<TeamWeek>([\.slug, \.weekStart])
    var slug: String
    var weekStart: Date
    var targetSum: UInt
    var identSum: UInt
    var members: [TeamMember]
    var teamStreak: UInt

    init(
        slug: String,
        weekStart: Date,
        targetSum: UInt,
        identSum: UInt,
        members: [TeamMember],
        teamStreak: UInt
    ) {
        self.slug = slug
        self.weekStart = AppCalendar.startOfWeek(containing: weekStart)
        self.targetSum = targetSum
        self.identSum = identSum
        self.members = members
        self.teamStreak = teamStreak
    }

    convenience init(dto: TeamWeekDTO) {
        self.init(
            slug: dto.slug,
            weekStart: dto.weekStart,
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
            weekStart: Date(),
            targetSum: 6,
            identSum: 3,
            members: [
                .templateGretaKanten,
                .templateNicoKanten,
            ],
            teamStreak: 2
        )
    }

    static var templateBadKanten: TeamWeek {
        TeamWeek(
            slug: "die-kanten",
            weekStart: AppCalendar.calendar.date(byAdding: .day, value: -7, to: Date())!,
            targetSum: 6,
            identSum: 1,
            members: [
                .templateGretaKanten,
                .templateNicoKanten,
            ],
            teamStreak: 0
        )
    }

    static var templateGoodkanten: TeamWeek {
        TeamWeek(
            slug: "die-kanten",
            weekStart: AppCalendar.calendar.date(byAdding: .day, value: -7, to: Date())!,
            targetSum: 6,
            identSum: 7,
            members: [
                .templateGretaKanten,
                .templateNicoKanten,
            ],
            teamStreak: 9
        )
    }
}

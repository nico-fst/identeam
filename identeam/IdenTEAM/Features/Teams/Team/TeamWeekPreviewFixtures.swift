import Foundation

/// Explicit injection keeps Canvas identity and navigation out of real account preferences.
nonisolated struct TeamWeekPreviewConfiguration {
    let userID: String
    let now: Date
    var detailed = false
    var card = 0
}

#if DEBUG

    /// Offline values shared by the Canvas and tests. Friday keeps every scenario reproducible.
    nonisolated enum TeamWeekPreviewFixtures {
        static let weekStart = AppCalendar.parseDate("2026-10-12")!

        static func make(
            scenario: TeamWeekPresentation.Scenario = .nearlyFinished,
            streak: Int = 3,
            weekStart: Date = TeamWeekPreviewFixtures.weekStart
        ) -> TeamWeekPresentation {
            let dates = AppCalendar.datesInWeek(containing: weekStart)
            var targets = [[0, 2, 6], [0, 2, 6], [0, 2, 6]]
            var completed: [[Int]] = [[], [], []]
            switch scenario {
            case .setGoal: targets[0] = []
            case .newWeek: break
            case .nearlyFinished: completed = [[0, 2], [0, 1, 2], [0, 1, 2]]
            case .catchingUp: completed = [[0], [0, 1, 2], [0, 2]]
            case .behind:
                targets[1] = [0, 1, 5, 6]
                completed = [[], [0, 1], [2]]
            case .personallyOnTrack:
                targets = [[0, 2, 6], [0, 5, 6], [0, 5, 6]]
                completed = [[0, 2], [0], [0]]
            case .teamOnTrack: completed = [[0, 2], [0, 2], [0, 2]]
            }
            let members = ["Nico", "Greta", "Veit"].enumerated().map { index, name in
                TeamWeekPresentation.Member(
                    id: String(index), name: name, targets: targets[index].map { dates[$0] },
                    idents: completed[index].map { day in
                        TeamWeekPresentation.Entry(
                            id: "\(index)-\(day)", time: dates[day].addingTimeInterval(12 * 3600))
                    })
            }
            return TeamWeekPresentation(
                weekStart: dates[0], members: members, currentUserID: "0", streak: max(0, streak),
                now: dates[4].addingTimeInterval(12 * 3600))
        }
    }
#endif

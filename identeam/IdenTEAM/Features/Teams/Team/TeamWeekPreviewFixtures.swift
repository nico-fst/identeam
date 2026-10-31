import Foundation

/// Explicit injection keeps Canvas identity and navigation out of real account preferences.
nonisolated struct TeamWeekPreviewConfiguration {
    let userID: String
    let now: Date
}

#if DEBUG

    /// Offline values shared by the Canvas and tests.
    /// Each card gets reproducible inputs, independently of how its view is rendered.
    nonisolated enum TeamWeekPreviewFixtures {
        static let weekStart = AppCalendar.parseDate("2026-10-12")!

        static func make(
            card: TeamWeekSummaryCard? = .aggressive(.nearlyFinished),
            streak: Int = 3,
            weekStart: Date = TeamWeekPreviewFixtures.weekStart
        ) -> TeamWeekPresentation {
            let dates = AppCalendar.datesInWeek(containing: weekStart)
            var targets = [[0, 2, 6], [0, 2, 6], [0, 2, 6]]
            var completed: [[Int]] = [[], [], []]
            switch card {
            case .action(.setGoal): targets[0] = []
            case .reaction(.newWeek): break
            case .aggressive(.nearlyFinished): completed = [[0, 2], [0, 1, 2], [0, 1, 2]]
            case .aggressive(.catchingUp): completed = [[0], [0, 1, 2], [0, 2]]
            case .aggressive(.behind):
                targets[1] = [0, 1, 5, 6]
                completed = [[], [0, 1], [2]]
            case .reaction(.personallyOnTrack):
                targets = [[0, 4, 6], [0, 5, 6], [0, 5, 6]]
                completed = [[0, 4], [0], [0]]
            case .reaction(.teamOnTrack): completed = [[0, 4], [0, 2], [0, 2]]
            case .reaction(.recap), .streak, nil: completed = [[0, 2], [0, 2], [0, 2]]
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
                now: (card == .reaction(.recap)
                    ? AppCalendar.calendar.date(byAdding: .weekOfYear, value: 1, to: dates[4])!
                    : dates[4]).addingTimeInterval(12 * 3600))
        }

        static func make(stage: Int, weekStart: Date = TeamWeekPreviewFixtures.weekStart)
            -> TeamWeekPresentation
        {
            let dates = AppCalendar.datesInWeek(containing: weekStart)
            let stage = min(4, max(0, stage))
            let completions: [[[Int]]] = [
                [[], [], []], [[], [0, 2], [0]],
                [[0, 2], [0, 2], [0, 2]],
                [[0, 2, 4], [0, 2, 4], [0, 2, 4]],
                [[0, 2, 4, 6], [0, 2, 4, 6], [0, 2, 4, 6]],
            ]
            let members = ["Nico", "Greta", "Veit"].enumerated().map { index, name in
                TeamWeekPresentation.Member(
                    id: String(index), name: name,
                    targets: stage == 0 && index == 0 ? [] : [0, 2, 4, 6].map { dates[$0] },
                    idents: completions[stage][index].map { day in
                        TeamWeekPresentation.Entry(id: "\(index)-\(day)", time: dates[day])
                    })
            }
            return TeamWeekPresentation(
                weekStart: weekStart, members: members, currentUserID: "0", streak: 3,
                now: dates[stage == 4 ? 6 : 4].addingTimeInterval(12 * 3600))
        }
    }
#endif

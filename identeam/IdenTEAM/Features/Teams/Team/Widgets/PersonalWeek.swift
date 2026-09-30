import Foundation

struct PersonalWeek {
    let weekStart: Date
    let identDates: [Date]
    let targetDates: [Date]

    var targetCount: Int {
        targetDates.count
    }

    var goalReached: Bool {
        targetCount > 0 && identDates.count >= targetCount
    }
}

extension PersonalWeek {
    init?(teamWeek: TeamWeek, userID: String) {
        guard let member = teamWeek.members.first(where: { $0.user.userID == userID }) else {
            return nil
        }

        self.init(
            weekStart: teamWeek.weekStart,
            identDates: member.idents.map(\.time),
            targetDates: member.targetDays
        )
    }
}

extension PersonalWeek {
    // March 2026 spans six calendar rows, including days in February and April.
    static var templateMonth: Date {
        AppCalendar.parseDate("2026-03-01")!
    }

    static var templateWeeks: [PersonalWeek] {
        [templateW1, templateW2, templateW3, templateW4, templateW5, templateW6]
    }

    // Feb 23–Mar 1: reached, including idents in the previous month.
    static var templateW1: PersonalWeek {
        templateWeek(offset: 0, targetCount: 3, identDayOffsets: [0, 4, 6])
    }

    // Mar 2–8: two of three idents; individual days only.
    static var templateW2: PersonalWeek {
        templateWeek(offset: 1, targetCount: 3, identDayOffsets: [1, 4, 5])
    }

    // Mar 9–15: four idents exceed a target of two.
    static var templateW3: PersonalWeek {
        templateWeek(offset: 2, targetCount: 2, identDayOffsets: [0, 2, 4, 6])
    }

    // Mar 16–22: activity without a goal must not mark the whole week.
    static var templateW4: PersonalWeek {
        templateWeek(offset: 3, targetCount: 0, identDayOffsets: [2])
    }

    // Mar 23–29: planned but no activity, across the daylight-saving change.
    static var templateW5: PersonalWeek {
        templateWeek(offset: 4, targetCount: 3, identDayOffsets: [])
    }

    // Mar 30–Apr 5: idents on Monday, Tuesday and Thursday reach the goal across months.
    static var templateW6: PersonalWeek {
        templateWeek(offset: 5, targetCount: 3, identDayOffsets: [0, 1, 3])
    }

    private static func templateWeek(
        offset: Int,
        targetCount: Int,
        identDayOffsets: [Int]
    ) -> PersonalWeek {
        let calendar = AppCalendar.calendar
        let firstWeek = AppCalendar.startOfWeek(containing: templateMonth)
        let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: firstWeek)!

        return PersonalWeek(
            weekStart: weekStart,
            identDates: identDayOffsets.enumerated().map { index, dayOffset in
                calendar.date(
                    byAdding: DateComponents(day: dayOffset, hour: 9 + index),
                    to: weekStart
                )!
            },
            targetDates: Array(AppCalendar.datesInWeek(containing: weekStart).prefix(targetCount))
        )
    }
}

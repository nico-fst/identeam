import Foundation

nonisolated enum TargetPlanning {
    static func canSetTargetWeek(_ date: Date, now: Date = Date()) -> Bool {
        AppCalendar.startOfWeek(containing: date) >= firstPlannableWeek(now: now)
    }

    static func firstPlannableWeek(now: Date = Date()) -> Date {
        if AppCalendar.calendar.component(.weekday, from: now) == 2 {
            return AppCalendar.startOfWeek(containing: now)
        }
        return AppCalendar.nextMonday(after: now)
    }

    static func weekName(for referenceDate: Date, now: Date = Date()) -> String {
        let thisWeek = AppCalendar.startOfWeek(containing: now)
        let weekStart = AppCalendar.startOfWeek(containing: referenceDate)

        return
            switch AppCalendar.calendar.dateComponents(
                [.weekOfYear],
                from: thisWeek,
                to: weekStart
            ).weekOfYear
        {  // offset in weeks
        case -1: "Last week"
        case 0: "This week"
        case 1: "Next week"
        case 2: "The week after next"
        default: "Week of \(AppCalendar.dateString(weekStart))"
        }
    }
}

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

        if weekStart == thisWeek {
            return "This week"
        }

        if let nextWeek = AppCalendar.calendar.date(byAdding: .day, value: 7, to: thisWeek),
           weekStart == nextWeek {
            return "Next week"
        }

        if let nextWeek = AppCalendar.calendar.date(byAdding: .day, value: 14, to: thisWeek),
           weekStart == nextWeek {
            return "The week after next"
        }

        return "Week of \(AppCalendar.dateString(weekStart))"
    }

}

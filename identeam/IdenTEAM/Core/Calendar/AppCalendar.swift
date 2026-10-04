import Foundation

nonisolated enum AppCalendar {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func daySlashMonth(for date: Date) -> String {
        date.formatted(
            .dateTime
                .day(.twoDigits)
                .month(.twoDigits)
        )
    }

    static func dayDotMonth(for date: Date) -> String {
        date.formatted(
            .dateTime
                .day(.twoDigits)
                .month(.twoDigits)
                .locale(Locale(identifier: "de_DE"))
        )
    }

    static func shortDateAndTime(for date: Date) -> String {
        date.formatted(
            .dateTime
                .day(.twoDigits)
                .month(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    static func weekdayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    static func nextMonday(
        after referenceDate: Date,
        calendar: Calendar = AppCalendar.calendar
    ) -> Date {
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let weekday = calendar.component(.weekday, from: startOfDay)
        var daysUntilMonday = (9 - weekday) % 7
        if daysUntilMonday == 0 {
            daysUntilMonday = 7
        }

        return calendar.date(
            byAdding: .day,
            value: daysUntilMonday,
            to: startOfDay
        )!
    }

    static func startOfWeek(
        containing date: Date,
        calendar: Calendar = AppCalendar.calendar
    ) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(
            byAdding: .day,
            value: -daysSinceMonday,
            to: day
        )!
    }

    static func startOfMonth(
        containing date: Date,
        calendar: Calendar = AppCalendar.calendar
    ) -> Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        )!
    }

    static func datesInWeek(containing date: Date = Date()) -> [Date] {
        let start = startOfWeek(containing: date)
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    static func weekStartsInMonth(containing date: Date) -> [Date] {
        let monthStart = startOfMonth(containing: date)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        var weekStart = startOfWeek(containing: monthStart)
        var weeks: [Date] = []

        while weekStart < nextMonth {
            weeks.append(weekStart)
            weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        }

        return weeks
    }
}

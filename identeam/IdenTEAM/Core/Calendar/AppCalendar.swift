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
    static func datesInWeek(containing date: Date) -> [Date] {
        let start = startOfWeek(containing: date)
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }
}

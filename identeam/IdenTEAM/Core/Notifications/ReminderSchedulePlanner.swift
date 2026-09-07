import Foundation

nonisolated struct LocalReminderDTO: Decodable {
    let title: String
    let body: String
    let date: Date
}

nonisolated enum ReminderSchedulePlanner {
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

    static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    static func isFutureWeek(_ date: Date, now: Date = Date()) -> Bool {
        startOfWeek(containing: date) > startOfWeek(containing: now)
    }

    static func nextMonday(
        after referenceDate: Date,
        calendar: Calendar = ReminderSchedulePlanner.calendar
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

    static func remindersForWeek(
        intelligentSuggestions: [LocalReminderDTO],
        defaultTime: DateComponents,
        teamName: String,
        dateStart: Date,
        targetDays: [Date],
        calendar: Calendar = ReminderSchedulePlanner.calendar
    ) -> [LocalReminderDTO] {
        let weekStart = startOfWeek(containing: dateStart, calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        let suggestionsByDay = Dictionary(
            intelligentSuggestions.map {
                (calendar.startOfDay(for: $0.date), $0)
            },
            uniquingKeysWith: { first, _ in first }
        )

        let plannedDays = Set(targetDays.map { calendar.startOfDay(for: $0) })
            .filter { $0 >= weekStart && $0 < weekEnd }
            .sorted()
        return plannedDays.compactMap { day in
            // if backend provided intelligent reminder: use it
            if let suggestion = suggestionsByDay[calendar.startOfDay(for: day)] {
                return suggestion
            }

            // otherwise: use user's default time
            var components = calendar.dateComponents(
                [.year, .month, .day],
                from: day
            )
            components.hour = defaultTime.hour ?? 18
            components.minute = defaultTime.minute ?? 0

            guard let date = calendar.date(from: components) else {
                return nil
            }

            return LocalReminderDTO(
                title: "⚠️ \(teamName) needs you ⚠️",
                body: "Time for your daily Ident.",
                date: date
            )
        }
    }

    static func startOfWeek(
        containing date: Date,
        calendar: Calendar = ReminderSchedulePlanner.calendar
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
}

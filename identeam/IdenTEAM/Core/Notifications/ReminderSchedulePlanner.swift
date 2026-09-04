import Foundation

struct LocalReminderDTO: Decodable {
    let title: String
    let body: String
    let date: Date
}

enum ReminderSchedulePlanner {
    static func nextMonday(
        after referenceDate: Date,
        calendar: Calendar = .current
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

    static func remindersForUpcomingWeek(
        intelligentSuggestions: [LocalReminderDTO],
        defaultTime: DateComponents,
        teamName: String,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [LocalReminderDTO] {
        let weekStart = intelligentSuggestions
            .map(\.date)
            .min()
            .map { startOfWeek(containing: $0, calendar: calendar) }
            ?? nextMonday(after: referenceDate, calendar: calendar)

        let suggestionsByDay = Dictionary(
            intelligentSuggestions.map {
                (calendar.startOfDay(for: $0.date), $0)
            },
            uniquingKeysWith: { first, _ in first }
        )

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(
                byAdding: .day,
                value: offset,
                to: weekStart
            ) else {
                return nil
            }

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

    private static func startOfWeek(
        containing date: Date,
        calendar: Calendar
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

import Foundation

nonisolated enum ReminderSchedulePlanner {
    static func remindersForWeek(
        intelligentSuggestions: [LocalReminderDTO],
        defaultTime: DateComponents,
        teamName: String,
        dateStart: Date,
        targetDays: [Date],
        calendar: Calendar = AppCalendar.calendar
    ) -> [LocalReminderDTO] {
        let weekStart = AppCalendar.startOfWeek(containing: dateStart, calendar: calendar)
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

}

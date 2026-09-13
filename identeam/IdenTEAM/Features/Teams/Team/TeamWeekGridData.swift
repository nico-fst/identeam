import Foundation

nonisolated enum TeamWeekGridCalendar {
    static func dates(containing date: Date) -> [Date] {
        let calendar = ReminderSchedulePlanner.calendar
        let start = ReminderSchedulePlanner.startOfWeek(containing: date)
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }
}

nonisolated struct MemberDay<IdentValue>: Identifiable {
    let date: Date
    let ident: IdentValue?
    let isTargetDay: Bool

    var id: Date { date }

    init(date: Date, idents: [IdentValue], time: KeyPath<IdentValue, Date>, targetDays: [Date]) {
        let calendar = ReminderSchedulePlanner.calendar
        self.date = date
        self.ident = idents
            .filter { calendar.isDate($0[keyPath: time], inSameDayAs: date) }
            .max { $0[keyPath: time] < $1[keyPath: time] }
        self.isTargetDay = targetDays.contains {
            calendar.isDate($0, inSameDayAs: date)
        }
    }
}


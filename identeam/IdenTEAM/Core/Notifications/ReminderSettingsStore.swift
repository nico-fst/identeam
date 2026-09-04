import Foundation

struct TeamReminderSettingsStore {
    static let shared = TeamReminderSettingsStore()

    // no direct @AppStorage since key:userId,slug varies per team
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func defaultTime(userID: String, slug: String) -> DateComponents {
        let minutes = defaults.object(forKey: key(userID: userID, slug: slug)) as? Int
            ?? 18 * 60
        return DateComponents(hour: minutes / 60, minute: minutes % 60)
    }

    func setDefaultTime(
        _ date: Date,
        userID: String,
        slug: String,
        calendar: Calendar = .current
    ) {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        defaults.set(hour * 60 + minute, forKey: key(userID: userID, slug: slug))
    }

    func dateForPicker(
        userID: String,
        slug: String,
        calendar: Calendar = .current
    ) -> Date {
        let time = defaultTime(userID: userID, slug: slug)
        return calendar.date(
            bySettingHour: time.hour ?? 18,
            minute: time.minute ?? 0,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func key(userID: String, slug: String) -> String {
        "identeam.reminder.defaultTime.\(userID).\(slug)"
    }
}

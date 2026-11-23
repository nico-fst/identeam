import Foundation

nonisolated enum TeamWeekImageSettings {
    static func key(for slug: String) -> String {
        "week.\(slug).weekgrid.showIdentImages"
    }

    static func showsImages(for slug: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key(for: slug)) as? Bool ?? false
    }

    static func setShowsImages(
        _ showImages: Bool, for slug: String, defaults: UserDefaults = .standard
    ) {
        defaults.set(showImages, forKey: key(for: slug))
    }
}

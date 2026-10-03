import SwiftData
import System
import WidgetKit

struct Provider: AppIntentTimelineProvider {
    // dummy data, e.g. in gallery
    func placeholder(in context: Context) -> WeekEntry {
        WeekEntry(date: Date(), week: .templateKanten)
    }

    // fast preview, e.g. in gallery preview
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> WeekEntry
    {
        let week = loadWeek(slug: TeamWeek.templateKanten.slug) ?? .templateKanten  // TODO "not found"

        return WeekEntry(date: Date(), week: week)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<
        WeekEntry
    > {
        let week = loadWeek(slug: configuration.team?.id) ?? .templateKanten  // TODO "not found"
        let entry = WeekEntry(date: Date(), week: week)

        return Timeline(
            entries: [entry],
            policy: .never
        )
    }

    private func loadWeek(slug: String?) -> TeamWeek? {
        guard let slug else { return nil }

        let container = SharedModelConfig.makeContainer(for: .widget)
        let context = ModelContext(container)

        let currentWeekStart = AppCalendar.startOfWeek(containing: Date())
        let descriptor = FetchDescriptor<TeamWeek>(
            predicate: #Predicate {
                $0.weekStart == currentWeekStart && $0.slug == slug
            }
        )

        return try? context.fetch(descriptor).first
    }
}

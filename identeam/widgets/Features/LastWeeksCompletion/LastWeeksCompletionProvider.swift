import SwiftData
import WidgetKit

struct LastWeeksCompletionEntry: TimelineEntry {
    let date: Date
    let weeks: [TeamWeek]
}

struct LastWeeksCompletionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LastWeeksCompletionEntry {
        LastWeeksCompletionEntry(date: Date(), weeks: [.templateGoodkanten, .templateKanten])
    }

    func snapshot(
        for configuration: ConfigurationAppIntent, in context: Context
    ) async -> LastWeeksCompletionEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        return loadEntry(slug: configuration.team?.id, date: Date())
    }

    func timeline(
        for configuration: ConfigurationAppIntent, in context: Context
    ) async -> Timeline<LastWeeksCompletionEntry> {
        let date = Date()
        return Timeline(
            entries: [loadEntry(slug: configuration.team?.id, date: date)],
            policy: .after(date.addingTimeInterval(60 * 60))
        )
    }

    private func loadEntry(slug: String?, date: Date) -> LastWeeksCompletionEntry {
        guard let slug else {
            return LastWeeksCompletionEntry(date: date, weeks: [])
        }
        let container = SharedModelConfig.makeContainer(for: .widget)
        let context = ModelContext(container)
        return LastWeeksCompletionEntry(
            date: date, weeks: Self.loadWeeks(in: context, slug: slug, date: date)
        )
    }

    static func loadWeeks(in context: ModelContext, slug: String, date: Date) -> [TeamWeek] {
        let currentWeek = AppCalendar.startOfWeek(containing: date)
        var descriptor = FetchDescriptor<TeamWeek>(
            predicate: #Predicate { $0.slug == slug && $0.weekStart <= currentWeek },
            sortBy: [SortDescriptor(\TeamWeek.weekStart, order: .reverse)]
        )
        descriptor.fetchLimit = 4
        let weeks = (try? context.fetch(descriptor)) ?? []
        // Detach the display values from the short-lived database context.
        return weeks.map {
            TeamWeek(
                slug: $0.slug, weekStart: $0.weekStart, targetSum: $0.targetSum,
                identSum: $0.identSum, members: [], teamStreak: $0.teamStreak
            )
        }
    }
}

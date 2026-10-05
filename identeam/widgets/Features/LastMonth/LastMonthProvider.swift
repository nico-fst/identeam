import SwiftData
import WidgetKit

struct LastMonthEntry: TimelineEntry {
    let date: Date
    let teamName: String
    let personalWeeks: [PersonalWeek]
    let currentWeek: TeamWeek?
}

struct LastMonthProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LastMonthEntry {
        LastMonthEntry(
            date: PersonalWeek.templateMonth, teamName: "Die Kanten",
            personalWeeks: PersonalWeek.templateWeeks, currentWeek: .templateStreakKanten
        )
    }

    func snapshot(
        for configuration: ConfigurationAppIntent, in context: Context
    ) async -> LastMonthEntry {
        if context.isPreview { return placeholder(in: context) }
        return loadEntry(team: configuration.team, date: Date())
    }

    func timeline(
        for configuration: ConfigurationAppIntent, in context: Context
    ) async -> Timeline<LastMonthEntry> {
        let date = Date()
        return Timeline(
            entries: [loadEntry(team: configuration.team, date: date)],
            policy: .after(date.addingTimeInterval(60 * 60))
        )
    }

    private func loadEntry(team: TeamEntity?, date: Date) -> LastMonthEntry {
        guard let team else {
            return LastMonthEntry(
                date: date, teamName: "Choose a team", personalWeeks: [], currentWeek: nil
            )
        }
        let container = SharedModelConfig.makeContainer(for: .widget)
        return Self.loadEntry(
            in: ModelContext(container), slug: team.id, teamName: team.name,
            userID: SharedModelConfig.widgetUserID, date: date
        )
    }

    static func loadEntry(
        in context: ModelContext, slug: String, teamName: String, userID: String?, date: Date
    ) -> LastMonthEntry {
        guard let userID, !userID.isEmpty else {
            return LastMonthEntry(
                date: date, teamName: teamName, personalWeeks: [], currentWeek: nil
            )
        }
        let starts = AppCalendar.weekStartsInMonth(containing: date)
        let firstWeek = starts[0]
        let lastWeek = starts[starts.count - 1]
        let descriptor = FetchDescriptor<TeamWeek>(
            predicate: #Predicate {
                $0.slug == slug && $0.weekStart >= firstWeek && $0.weekStart <= lastWeek
            },
            sortBy: [SortDescriptor(\TeamWeek.weekStart)]
        )
        let weeks = (try? context.fetch(descriptor)) ?? []
        let currentStart = AppCalendar.startOfWeek(containing: date)
        let current = weeks.first { $0.weekStart == currentStart }
        let teamDescriptor = FetchDescriptor<Team>(predicate: #Predicate { $0.slug == slug })
        let cachedName = (try? context.fetch(teamDescriptor))?.first?.name

        // Copy display values before the short-lived database context is released.
        return LastMonthEntry(
            date: date, teamName: cachedName ?? teamName,
            personalWeeks: weeks.compactMap { PersonalWeek(teamWeek: $0, userID: userID) },
            currentWeek: current.map {
                TeamWeek(
                    slug: $0.slug, weekStart: $0.weekStart, targetSum: $0.targetSum,
                    identSum: $0.identSum, members: [], teamStreak: $0.teamStreak
                )
            }
        )
    }
}

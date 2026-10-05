import SwiftUI
import WidgetKit

struct LastMonthWidget: Widget {
    let kind = "lastMonth"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind, intent: ConfigurationAppIntent.self, provider: LastMonthProvider()
        ) { entry in
            LastMonthWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Month Overview")
        .description("See your month and your team's current progress.")
        .supportedFamilies([.systemMedium])
    }
}

struct LastMonthWidgetView: View {
    let entry: LastMonthEntry

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                currentWeekSummary
                    .frame(width: geometry.size.width * 1 / 3)

                let rowCount = AppCalendar.weekStartsInMonth(containing: entry.date).count
                let calendarHeight = geometry.size.height - 24 - CGFloat(rowCount - 1) * 4
                LastMonthView(
                    month: entry.date, personalWeeks: entry.personalWeeks,
                    referenceDate: entry.date,
                    dayHeight: max(1, min(24, calendarHeight / CGFloat(rowCount))),
                    rowSpacing: 4
                )
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .frame(width: geometry.size.width * 2 / 3, height: geometry.size.height)
            }
            .frame(height: geometry.size.height)
        }
    }

    private var currentWeekSummary: some View {
        VStack(spacing: 8) {
            Text(entry.teamName)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            let week = entry.currentWeek
            let completed = week.map { $0.targetSum > 0 && $0.identSum >= $0.targetSum } ?? false
            FilledFlash(
                progress: week.map {
                    $0.targetSum > 0 ? Double($0.identSum) / Double($0.targetSum) : 0
                } ?? 0,
                color: week == nil ? .primary.opacity(0.15) : (completed ? .accent : .red),
                text: week.map { "\($0.identSum) / \($0.targetSum)" } ?? "",
                animated: false
            )
            .frame(height: 80)
            .aspectRatio(0.5, contentMode: .fit)

            TeamStreakLabel(week: week)
                .labelStyle(CompactStreakLabelStyle())
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, 4)
    }
}

#Preview(as: .systemMedium) {
    LastMonthWidget()
} timeline: {
    LastMonthEntry(
        date: PersonalWeek.templateMonth, teamName: "Die Kanten",
        personalWeeks: PersonalWeek.templateWeeks, currentWeek: .templateStreakKanten
    )
    LastMonthEntry(date: Date(), teamName: "Choose a team", personalWeeks: [], currentWeek: nil)
}

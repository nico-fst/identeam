import SwiftUI
import WidgetKit

struct LastMonthWidget: Widget {
    let kind = "lastMonth"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind, intent: ConfigurationAppIntent.self, provider: LastMonthProvider()
        ) { entry in
            LastMonthWidgetView(entry: entry)
                .foregroundStyle(AppColor.text)
                .tint(AppColor.link)
                .containerBackground(AppColor.surface, for: .widget)
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
                    .frame(width: geometry.size.width * 1 / 2)

                let rowCount = AppCalendar.weekStartsInMonth(containing: entry.date).count
                let calendarHeight = geometry.size.height - 24 - CGFloat(rowCount - 1) * 4

                VStack(spacing: 0) {
                    Text(entry.teamName)
                        .font(.footnote)
                        .bold()
                        .foregroundStyle(AppColor.link)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    LastMonthView(
                        month: entry.date, personalWeeks: entry.personalWeeks,
                        referenceDate: entry.date,
                        dayHeight: max(1, min(24, calendarHeight / CGFloat(rowCount))),
                        rowSpacing: 4
                    )
                    .font(.system(size: 10))

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .frame(
                    width: geometry.size.width * 1 / 2,
                    height: geometry.size.height
                )
            }
            .frame(height: geometry.size.height)
        }
    }

    private var currentWeekSummary: some View {
        let week = entry.currentWeek
        let completed = week.map { $0.targetSum > 0 && $0.identSum >= $0.targetSum } ?? false

        return VStack(spacing: 8) {
            Spacer()
            TeamStreakLabel(week: week)
                .labelStyle(CompactStreakLabelStyle())
                .bold()
                .foregroundStyle(completed ? AppColor.streak : AppColor.team)
        }
        .padding(10)
        .background {
            FilledFlash(
                progress: week.map {
                    $0.targetSum > 0 ? Double($0.identSum) / Double($0.targetSum) : 0
                } ?? 0,
                color: week == nil
                    ? AppColor.muted.opacity(0.15) : (completed ? AppColor.success : .accent),
                text: week.map { "\($0.identSum) / \($0.targetSum)" } ?? "",
                animated: false
            )
            .frame(width: 250, height: 250)
            .shadow(
                color: completed ? AppColor.success.opacity(0.5) : Color.accent.opacity(0.5),
                radius: 20,
                x: 0,
                y: 5
            )
        }
    }
}

#Preview(as: .systemMedium) {
    LastMonthWidget()
} timeline: {
    LastMonthEntry(
        date: PersonalWeek.templateMonth,
        teamName: "Die Kanten",
        personalWeeks: PersonalWeek.templateWeeks,
        currentWeek: .templateStreakKanten
    )
    LastMonthEntry(
        date: PersonalWeek.templateMonth,
        teamName: "Other team",
        personalWeeks: PersonalWeek.templateWeeks,
        currentWeek: .templateKanten
    )
    LastMonthEntry(
        date: PersonalWeek.templateMonth,
        teamName: "Very long team name really long",
        personalWeeks: PersonalWeek.templateWeeks,
        currentWeek: .templateBadKanten
    )
}

import SwiftUI

/// Shared content for the app section and the WidgetKit extension.
struct LastWeeksCompletionView: View {
    let lastWeeks: [TeamWeek]
    var referenceDate: Date = Date()
    var animated = false

    var lastWeeksSorted: [TeamWeek] {
        Array(
            lastWeeks
                .sorted { $0.weekStart < $1.weekStart }
                .suffix(4)
        )
    }

    func completed(_ week: TeamWeek) -> Bool {
        return week.targetSum > 0 && week.targetSum <= week.identSum
    }

    var weekLabels: [String] {
        lastWeeksSorted.enumerated().map { index, week in
            switch index {
            case lastWeeksSorted.count - 1:
                "Current"
            case lastWeeksSorted.count - 2:
                "Last"
            default:
                AppCalendar.dayDotMonth(for: week.weekStart)
            }
        }
    }

    var placeholderCount: Int {
        max(0, 4 - lastWeeksSorted.count)
    }

    var body: some View {
        HStack {
            // placeholder when not enough weeks
            ForEach(0..<placeholderCount, id: \.self) { _ in
                VStack {
                    Text(" ")
                        .font(.nunito(.footnote))

                    FilledFlash(
                        progress: 0,
                        color: IgniteColor.muted.opacity(0.15),
                        text: "",
                        animated: false
                    )
                    .frame(height: 80)
                    .aspectRatio(0.5, contentMode: .fit)

                    Text("No data")
                        .frame(maxWidth: .infinity)
                        .font(.nunito(.footnote))
                }
                .foregroundStyle(IgniteColor.text.opacity(0.15))
            }

            ForEach(Array(lastWeeksSorted.enumerated()), id: \.element) { i, week in
                VStack {
                    Text(weekLabels[i])
                        .font(.nunito(.footnote))
                        .opacity(0.5)

                    FilledFlash(
                        progress: week.targetSum > 0
                            ? Double(week.identSum) / Double(week.targetSum)
                            : 0,
                        color: completed(week) ? IgniteColor.success : .accent,
                        text: "\(week.identSum) / \(week.targetSum)",
                        animated: animated
                            && AppCalendar.calendar.isDate(
                                week.weekStart,
                                equalTo: referenceDate,
                                toGranularity: .weekOfYear
                            )
                    )
                    .frame(height: 80)
                    .aspectRatio(0.5, contentMode: .fit)

                    let streakLabel = TeamStreakLabel(
                        week: week,
                        context: .completion(isLatestWeek: week == lastWeeksSorted.last)
                    )
                    if completed(week) {
                        streakLabel
                            .labelStyle(CompactStreakLabelStyle())
                            .bold()
                            .font(.system(size: 13))
                            .foregroundStyle(IgniteColor.streak)
                    } else {
                        if week == lastWeeksSorted.last {
                            streakLabel.labelStyle(.iconOnly)
                        } else {
                            streakLabel.labelStyle(.iconOnly)
                                .foregroundStyle(IgniteColor.team)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    LastWeeksCompletionView(lastWeeks: [.templateGoodkanten, .templateKanten])
        .padding()
}

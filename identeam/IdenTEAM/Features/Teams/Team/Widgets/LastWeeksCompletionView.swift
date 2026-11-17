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

    private func isCurrent(_ week: TeamWeek) -> Bool {
        AppCalendar.startOfWeek(containing: week.weekStart)
            == AppCalendar.startOfWeek(containing: referenceDate)
    }

    var weekLabels: [String] {
        let previous = AppCalendar.calendar.date(byAdding: .day, value: -7, to: referenceDate)!
        return lastWeeksSorted.map { week in
            if isCurrent(week) { return "Current" }
            if AppCalendar.startOfWeek(containing: week.weekStart)
                == AppCalendar.startOfWeek(containing: previous)
            {
                return "Last"
            }
            return AppCalendar.dayDotMonth(for: week.weekStart)
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

                    ProgressFlash(
                        completed: 0, target: 0,
                        color: AppColor.muted.opacity(0.15),
                        animated: false, showsRatio: false
                    )
                    .frame(height: 80)

                    Text("No data")
                        .frame(maxWidth: .infinity)
                        .font(.nunito(.footnote))
                }
                .foregroundStyle(AppColor.text.opacity(0.15))
            }

            // This history belongs to one team. Dates stay stable when SwiftData persists its models.
            ForEach(Array(lastWeeksSorted.enumerated()), id: \.element.weekStart) { i, week in
                VStack {
                    Text(weekLabels[i])
                        .font(.nunito(.footnote))
                        .opacity(0.5)

                    ProgressFlash(
                        completed: Int(week.identSum), target: Int(week.targetSum),
                        color: completed(week)
                            ? AppColor.success
                            : isCurrent(week) ? AppColor.accent : AppColor.team,
                        animated: animated
                            && AppCalendar.calendar.isDate(
                                week.weekStart,
                                equalTo: referenceDate,
                                toGranularity: .weekOfYear
                            )
                    )
                    .frame(height: 80)

                    let streakLabel = TeamStreakLabel(
                        week: week,
                        context: .completion(isLatestWeek: isCurrent(week))
                    )
                    if completed(week) {
                        streakLabel
                            .labelStyle(CompactStreakLabelStyle())
                            .bold()
                            .font(.system(size: 13))
                            .foregroundStyle(AppColor.streak)
                    } else {
                        streakLabel.labelStyle(.iconOnly)
                            .foregroundStyle(AppColor.team)
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

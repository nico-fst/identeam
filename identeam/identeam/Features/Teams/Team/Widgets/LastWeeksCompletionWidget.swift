import SwiftUI

struct LastWeeksCompletionWidget: View {
    let lastWeeks: [TeamWeek]

    var lastWeeksSorted: [TeamWeek] {
        Array(
            lastWeeks
                .sorted { $0.weekStart < $1.weekStart }
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
                AppCalendar.daySlashMonth(for: week.weekStart)
            }
        }
    }

    var body: some View {
        Section {
            HStack {
                // placeholder when not enough weeks
                let countPlaceholders = 4 - lastWeeks.count
                ForEach(0..<countPlaceholders, id: \.self) { _ in
                    VStack {
                        Text(" ")
                            .font(.footnote)

                        FilledFlash(
                            progress: 0,
                            color: .primary.opacity(0.2),
                            text: "X",
                            animated: false
                        )
                        .frame(height: 80)
                        .aspectRatio(0.5, contentMode: .fit)

                        Text("No data")
                            .frame(maxWidth: .infinity)
                            .font(.footnote)
                    }
                    .foregroundStyle(.primary.opacity(0.2))
                }

                ForEach(Array(lastWeeksSorted.enumerated()), id: \.element) { i, week in
                    VStack {
                        Text(weekLabels[i])
                            .font(.footnote)
                            .opacity(0.5)

                        FilledFlash(
                            progress: week.targetSum > 0
                                ? Double(week.identSum) / Double(week.targetSum)
                                : 0,
                            color: completed(week) ? .accent : .red,
                            text: "\(week.identSum) / \(week.targetSum)",
                            animated: AppCalendar.calendar.isDate(
                                week.weekStart,
                                equalTo: Date(),
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
                                .foregroundStyle(.orange)
                        } else {
                            if week == lastWeeksSorted.last {
                                streakLabel.labelStyle(.iconOnly)
                            } else {
                                streakLabel.labelStyle(.iconOnly)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Completion of last weeks")
        }
    }
}

#Preview {
    List {
        LastWeeksCompletionWidget(
            lastWeeks: [
                .templateGoodkanten,
                .templateBadKanten,
                .templateKanten,
                .templateFrozenKanten,
            ]
        )
    }
    .listStyle(.insetGrouped)
}

import SwiftUI

struct CurrentProgressWidget: View {
    let week: TeamWeek

    @AppStorage private var showMembersWithoutTarget: Bool

    init(week: TeamWeek) {
        self.week = week
        _showMembersWithoutTarget = AppStorage(
            wrappedValue: true, "week.\(week.slug).weekgrid.showMembersWithoutTarget")
    }

    var body: some View {
        Section {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    progressSummary
                        .frame(width: geometry.size.width * 3 / 10)

                    Spacer()

                    memberFigures
                        .frame(width: geometry.size.width * 6 / 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 150)
        } header: {
            Text("Progress Overview")
                .font(.nunito(.headline))
        }
    }

    private var progress: Double {
        week.targetSum > 0
            ? Double(week.identSum) / Double(week.targetSum)
            : 0
    }

    private var progressSummary: some View {
        ZStack {
            FilledFlash(
                progress: progress,
                color: .accent,
                text: "\(week.identSum) / \(week.targetSum)",
                animated: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            streakBadge
                .offset(x: 25, y: 55)
        }
    }

    private var streakBadge: some View {
        TeamStreakLabel(week: week)
            .labelStyle(CompactStreakLabelStyle())
            .bold()
            .foregroundStyle(
                week.teamStreak > 0
                    ? IgniteColor.streak.opacity(0.9)
                    : IgniteColor.team
            )
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
    }

    private var memberFigures: some View {
        let maximumTargetCount = week.members.map { $0.targetDays.count }.max() ?? 0

        var members = week.members.sorted {
            $0.user.username.lowercased() < $1.user.username.lowercased()
        }
        if !showMembersWithoutTarget {
            members =
                members
                .filter { $0.targetDays.count > 0 }
        }

        return HStack(spacing: 4) {
            ForEach(members, id: \.self) { member in
                GrowingUserFigure(member: member)
                    .relativeFigureHeight(
                        targetCount: member.targetDays.count,
                        maximumTargetCount: maximumTargetCount
                    )
            }
        }
    }
}

#Preview("List(CurrentProgressWidget)") {
    List {
        Group {
            CurrentProgressWidget(week: .templateStreakKanten)
        }
        .listRowBackground(IgniteColor.surface)
    }
    .igniteListColors()
    .listStyle(.insetGrouped)
}

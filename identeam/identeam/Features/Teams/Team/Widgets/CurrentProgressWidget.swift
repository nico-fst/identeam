import SwiftUI

struct CurrentProgressWidget: View {
    let week: TeamWeek

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
            Text("Current Progress")
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

            VStack {
                Spacer()
                streakBadge
            }
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 2) {
            Text(String(week.teamStreak))
                .bold()
            
            if week.teamStreak > 0 {
                Image(systemName: "flame.fill")
            } else {
                Image(systemName: "snowflake")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(week.teamStreak > 0
                    ? .orange.opacity(0.9)
                      : .blue.opacity(0.9)
                 )
        )
        .scaleEffect(0.75)
    }

    private var memberFigures: some View {
        let maximumTargetCount = week.members.map { $0.targetDays.count }.max() ?? 0

        return HStack(spacing: 0) {
            ForEach(week.members, id: \.self) { member in
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
        CurrentProgressWidget(week: .templateKanten)
    }
    .listStyle(.insetGrouped)
}

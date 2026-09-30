import SwiftUI

struct TeamStreakLabel: View {
    enum Context {
        case streak
        case completion(isLatestWeek: Bool)
    }

    let week: TeamWeek?
    var context: Context = .streak

    var presentation: (title: String, systemImage: String) {
        guard let week else { return ("...", "flame.fill") }

        switch context {
        case .streak:
            return (String(week.teamStreak), week.teamStreak > 0 ? "flame.fill" : "snowflake")
        case .completion(let isLatestWeek):
            if week.targetSum > 0 && week.identSum >= week.targetSum {
                return (String(week.teamStreak), "flame.fill")
            }
            return isLatestWeek
                ? ("Week in progress", "clock.badge.questionmark")
                : ("Goal not reached", "snowflake")
        }
    }

    var body: some View {
        Label(presentation.title, systemImage: presentation.systemImage)
    }
}

struct CompactStreakLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.icon
            configuration.title
        }
    }
}

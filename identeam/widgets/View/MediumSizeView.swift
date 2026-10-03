import SwiftData
import SwiftUI
import WidgetKit

struct MediumSizeView: View {
    var entry: Provider.Entry

    var body: some View {
        Text(entry.week.slug)
        Text("\(entry.week.identSum) / \(entry.week.targetSum)")
        Text("Streak: \(entry.week.teamStreak)")
    }
}

#Preview(as: .systemMedium) {
    Widgets()
} timeline: {
    WeekEntry(
        date: Date(),
        week: .templateStreakKanten
    )
}

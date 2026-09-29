import SwiftUI

struct LastWeeksCompletionWidget: View {
    let lastWeeks: [TeamWeek]

    var body: some View {
        Section {
            HStack {
                ForEach(lastWeeks, id: \.self) { week in
                    FilledFlash(
                        progress: week.targetSum > 0
                            ? Double(week.identSum) / Double(week.targetSum)
                            : 0,
                        color: .accent,
                        text: "\(week.identSum) / \(week.targetSum)",
                        animated: false
                    )
                }
            }
        }
    }
}

#Preview {
    List {
        LastWeeksCompletionWidget(
            lastWeeks: [.templateKanten, .templateBadKanten, .templateGoodkanten]
        )
    }
    .listStyle(.insetGrouped)
}

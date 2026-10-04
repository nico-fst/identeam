import SwiftData
import SwiftUI
import WidgetKit

struct LastWeeksCompletionWidget: Widget {
    let kind = "lastWeeksCompletion"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: LastWeeksCompletionProvider()
        ) { entry in
            LastWeeksCompletionView(lastWeeks: entry.weeks, referenceDate: entry.date)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Completion of last weeks")
        .description("See your team's progress over the last four weeks.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    LastWeeksCompletionWidget()
} timeline: {
    LastWeeksCompletionEntry(
        date: Date(),
        weeks: [
            .templateFrozenKanten, .templateBadKanten, .templateGoodkanten, .templateStreakKanten,
        ])
    LastWeeksCompletionEntry(date: Date(), weeks: [.templateGoodkanten, .templateKanten])
    LastWeeksCompletionEntry(date: Date(), weeks: [])
}

import SwiftData
import SwiftUI
import WidgetKit

struct WidgetsEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: Provider.Entry

    var body: some View {
        switch widgetFamily {
        case .systemMedium:
            MediumSizeView(entry: entry)
        default:
            Text("Never executed, but switch has to be exhaustive")
        }
    }
}

@main
struct Widgets: Widget {
    let kind: String = "widgets"

    private let container: ModelContainer = {
        do {
            return try ModelContainer(
                // can access file from target 'identeam' since target 'Widgets' also has membership on file
                for: SharedModelConfig.schema,
                configurations: SharedModelConfig.config
            )
        } catch {
            fatalError("ERROR creating widget ModelContainer: \(error)")
        }
    }()

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            WidgetsEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
                .modelContainer(container)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    Widgets()
} timeline: {
    WeekEntry(date: Date(), week: .templateStreakKanten)
}

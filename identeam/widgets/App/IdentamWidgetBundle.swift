import SwiftUI
import WidgetKit

@main
struct IdentamWidgetBundle: WidgetBundle {
    var body: some Widget {
        LastWeeksCompletionWidget()
        LastMonthWidget()
    }
}

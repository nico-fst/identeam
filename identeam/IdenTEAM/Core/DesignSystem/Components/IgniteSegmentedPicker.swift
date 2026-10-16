import SwiftUI

/// Uses the native segmented control so iOS owns tracking and Liquid Glass interactions.
struct IgniteSegmentedPicker<Selection: Hashable>: View {
    let title: String
    @Binding var selection: Selection
    let options: [Selection]
    let label: (Selection) -> String

    init(
        _ title: String, selection: Binding<Selection>, options: [Selection],
        label: @escaping (Selection) -> String
    ) {
        self.title = title
        _selection = selection
        self.options = options
        self.label = label
    }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option)).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}

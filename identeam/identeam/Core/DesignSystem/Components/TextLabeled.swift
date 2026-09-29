import SwiftUI

struct TextLabeled: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .contextMenu {  // manual since iOS27 changed .textSelection behavior
                    Button {
                        UIPasteboard.general.string = value
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                .lineLimit(1)
        }
    }
}

#Preview {
    TextLabeled("Label", "Text Value")
}

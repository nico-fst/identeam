import SwiftUI

/// Both comment surfaces share this displacement and the same dismissal transaction.
struct IdentPanelDrag: ViewModifier {
    @Binding var offset: CGFloat
    let canStart: Bool
    let onDismiss: () -> Void
    @State private var allowed: Bool?

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .global)
                .onChanged { value in
                    if allowed == nil { allowed = canStart }
                    if allowed == true, value.translation.height > abs(value.translation.width) {
                        offset = max(0, value.translation.height)
                    }
                }
                .onEnded { value in
                    let dismiss =
                        allowed == true
                        && IdentDetailGesture.dismissComments(
                            translation: value.translation, predicted: value.predictedEndTranslation
                        )
                    allowed = nil
                    if dismiss {
                        onDismiss()
                    } else {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) { offset = 0 }
                    }
                }
        )
    }
}

import Observation
import SwiftUI
import UIKit

struct IdentFlashSource {
    let frame: CGRect
    let color: Color
    let showsImage: Bool
}

/// Owns the one active Ident and the staged flight from its original screen position.
@Observable
final class IdentDetailPresentation {
    struct Selection: Identifiable {
        let id = UUID()
        let ident: Ident
        let author: User
        let slug: String
        let source: IdentFlashSource
        let teamVM: TeamWeekVM
        var identID: String { TeamWeekPresentation.identID(ident) }
    }

    enum Phase: Int, Comparable {
        case source, lifted, hero, smallDot, largeDot, thought
        // .rawValue is 0, 1, 2, ... since type Int
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private struct Step {
        let delay: Duration
        let phase: Phase
        let animation: Animation
    }

    private(set) var selection: Selection?
    private(set) var phase: Phase = .source
    private(set) var isClosing = false

    func present(
        ident: Ident, author: User, slug: String, source: IdentFlashSource, teamVM: TeamWeekVM
    ) {
        guard selection == nil else { return }
        phase = .source
        isClosing = false
        teamVM.selectedIdent = ident
        teamVM.commentInput = ""
        teamVM.commentError = ""
        selection = Selection(
            ident: ident, author: author, slug: slug, source: source, teamVM: teamVM)
    }

    func animateIn() async {
        guard let id = selection?.id else { return }
        let steps: [Step] = [
            .init(
                delay: .milliseconds(20), phase: .lifted,
                animation: .spring(duration: 0.20, bounce: 0.24)),
            .init(
                delay: .milliseconds(90), phase: .hero,
                animation: .spring(duration: 0.62, bounce: 0.30)),
            .init(
                delay: .milliseconds(260), phase: .smallDot,
                animation: .spring(duration: 0.44, bounce: 0.10)),
            .init(
                delay: .milliseconds(110), phase: .largeDot,
                animation: .spring(duration: 0.24, bounce: 0.22)),
            .init(
                delay: .milliseconds(130), phase: .thought,
                animation: .spring(duration: 0.4, bounce: 0.16)),
        ]
        for step in steps {
            do { try await Task.sleep(for: step.delay) } catch { return }
            guard selection?.id == id, !isClosing else { return }
            withAnimation(step.animation) { phase = step.phase }
        }
    }

    func dismiss(alongside updates: () -> Void = {}) async {
        guard let selection, !isClosing else { return }
        isClosing = true
        withAnimation(.spring(duration: 0.48, bounce: 0.10)) {
            phase = .source
            updates()
        }
        try? await Task.sleep(for: .milliseconds(480))
        selection.teamVM.selectedIdent = nil
        selection.teamVM.commentInput = ""
        selection.teamVM.commentError = ""
        self.selection = nil
    }
}

/// All frames use the overlay's local coordinates; the tapped frame arrives in screen coordinates.
struct IdentDetailLayout {
    let size: CGSize
    let safeArea: EdgeInsets
    var composerHeight: CGFloat = 76

    var flash: CGRect {
        let side = min(size.width * 1.10, max(96, size.height * 0.50))
        return CGRect(
            x: (size.width - side) / 2, y: safeArea.top + min(28, size.height * 0.04), width: side,
            height: side)
    }

    var comments: CGRect {
        let top = flash.maxY - 34
        return CGRect(
            x: 12, y: top, width: size.width - 24,
            height: max(0, size.height - top - max(12, safeArea.bottom) - 8 - composerHeight - 12))
    }

    func flashFrame(phase: IdentDetailPresentation.Phase, source: CGRect, overlayOrigin: CGPoint)
        -> CGRect
    {
        let local = source.offsetBy(dx: -overlayOrigin.x, dy: -overlayOrigin.y)
        switch phase {
        case .source: return local
        case .lifted:
            return local.insetBy(dx: -local.width * 0.12, dy: -local.height * 0.12)
                .offsetBy(dx: 0, dy: -16)
        default: return flash
        }
    }
}

/// Hardware/window geometry deliberately excludes keyboard avoidance.
struct IdentDetailViewport: Equatable {
    var size: CGSize = .zero
    var safeArea = EdgeInsets()
}

enum IdentDetailGesture {
    static func resistedThoughtDrag(_ translation: CGSize) -> CGSize {
        let distance = hypot(translation.width, translation.height)
        guard distance > 0 else { return .zero }
        let limit: CGFloat = 88
        let scale = limit * (1 - exp(-distance / limit)) / distance  // slow down exponentially when dragging
        return CGSize(width: translation.width * scale, height: translation.height * scale)
    }

    static func dismissFlash(translation: CGSize) -> Bool {
        hypot(translation.width, translation.height) > 8
    }
    static func dismissComments(translation: CGSize, predicted: CGSize) -> Bool {
        translation.height > 12 && translation.height > abs(translation.width)
            && (translation.height > 70 || predicted.height > 140)
    }
}

extension EnvironmentValues {
    @Entry var identDetailPresentation: IdentDetailPresentation?
}

private struct IdentDetailHost: ViewModifier {
    @State private var presentation = IdentDetailPresentation()
    @State private var viewport = IdentDetailViewport()

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(presentation.selection == nil)
            .background(IdentDetailWindowInsets { viewport = $0 })
            .overlay(alignment: .topLeading) {
                if let selection = presentation.selection {
                    IdentDetailView(
                        selection: selection, presentation: presentation,
                        viewport: viewport
                    )
                    .ignoresSafeArea(.container, edges: [.top, .leading, .trailing])
                    .environmentObject(selection.teamVM)
                    .id(selection.id)
                    .zIndex(100)
                }
            }
            .environment(\.identDetailPresentation, presentation)
    }
}

/// The launch/TabView containers consume SwiftUI's insets. Read the hosting window's hardware insets.
private struct IdentDetailWindowInsets: UIViewRepresentable {
    let onChange: (IdentDetailViewport) -> Void

    func makeUIView(context: Context) -> InsetsView { InsetsView(onChange: onChange) }
    func updateUIView(_ view: InsetsView, context: Context) {
        view.onChange = onChange
        view.reportInsets()
    }

    final class InsetsView: UIView {
        var onChange: (IdentDetailViewport) -> Void
        private var previousViewport: IdentDetailViewport?

        init(onChange: @escaping (IdentDetailViewport) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { return nil }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportInsets()
        }
        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            reportInsets()
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            reportInsets()
        }

        func reportInsets() {
            guard let window else { return }
            let insets = window.safeAreaInsets
            let value = IdentDetailViewport(
                size: window.bounds.size,
                safeArea: EdgeInsets(
                    top: insets.top, leading: insets.left,
                    bottom: insets.bottom, trailing: insets.right))
            guard previousViewport != value else { return }
            previousViewport = value
            DispatchQueue.main.async { [weak self] in self?.onChange(value) }
        }
    }
}

extension View {
    func identDetailOverlay() -> some View { modifier(IdentDetailHost()) }
}

import SwiftUI

/// Keeps startup above authentication sheets while the app prepares underneath.
struct LaunchScreen<RootView: View>: Scene {
    @ViewBuilder var rootContent: RootView

    var body: some Scene {
        WindowGroup {
            rootContent.modifier(LaunchScreenModifier())
        }
    }
}

private struct LaunchScreenModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var splashWindow: UIWindow?
    @State private var didPresent = false
    @State private var rootVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(rootVisible ? 1 : 0)
            .background(AppColor.accent.ignoresSafeArea())
            .onAppear { presentIfNeeded() }
            .onChange(of: scenePhase) { presentIfNeeded() }
    }

    private func presentIfNeeded() {
        guard !didPresent,
            let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState != .background })
        else { return }
        didPresent = true
        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        window.backgroundColor = .clear
        window.isOpaque = false
        let controller = UIHostingController(
            rootView: LaunchScreenView(
                captureFlash: {
                    snapshotFlash(in: window)
                },
                onReveal: {
                    rootVisible = true
                }
            ) {
                window.isHidden = true
                window.rootViewController = nil
                splashWindow = nil
                rootVisible = true
            })
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false
        window.rootViewController = controller
        splashWindow = window
        window.isHidden = false
    }

    private func snapshotFlash(in window: UIWindow) -> UIImage? {
        let side = LaunchScreenGeometry(size: window.bounds.size).flashSide
        let origin = CGPoint(
            x: (window.bounds.width - side) / 2, y: (window.bounds.height - side) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.traitCollection.displayScale
        var didDraw = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
            .image { _ in
                didDraw = window.drawHierarchy(
                    in: CGRect(
                        origin: CGPoint(x: -origin.x, y: -origin.y), size: window.bounds.size),
                    afterScreenUpdates: false)
            }
        return didDraw ? image : nil
    }
}

/// FlashShape retains the icon's square viewBox, including its original padding.
struct LaunchScreenGeometry {
    let size: CGSize

    var flashSide: CGFloat { min(size.width * 0.96, size.height * 0.62) }

    // The flash contains a central disc of radius > 8% of its viewBox.
    // Expand that disc beyond the screen diagonal, also on iPad and in landscape.
    var exitScale: CGFloat { hypot(size.width, size.height) / max(1, flashSide * 0.16) }
}

struct LaunchScreenView: View {
    var captureFlash: () -> UIImage? = { nil }
    var onReveal: () -> Void = {}
    let onComplete: () -> Void
    @State private var fill: CGFloat = 0
    @State private var glassSnapshot: UIImage?
    @State private var phase = Phase.glass

    private enum Phase { case glass, filling, anticipating, revealing }

    var body: some View {
        GeometryReader { geometry in
            let layout = LaunchScreenGeometry(size: geometry.size)
            let scale = phase == .revealing ? layout.exitScale : phase == .anticipating ? 0.88 : 1
            let rotation = phase == .revealing ? 90.0 : phase == .anticipating ? -9.0 : 0
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.98, green: 0.56, blue: 0.32), location: 0),
                        .init(color: AppColor.accent, location: 0.45),
                        .init(color: Color(red: 0.73, green: 0.25, blue: 0.09), location: 1),
                    ], startPoint: .top, endPoint: .bottom
                )
                .mask {
                    ZStack {
                        Rectangle()
                        FlashShape()
                            .frame(width: layout.flashSide, height: layout.flashSide)
                            .scaleEffect(scale)
                            .rotationEffect(.degrees(rotation), anchor: .center)
                            .opacity(phase == .revealing ? 1 : 0)
                            .blendMode(.destinationOut)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .compositingGroup()
                }

                flash
                    .frame(width: layout.flashSide, height: layout.flashSide)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation), anchor: .center)
                    .opacity(phase == .revealing ? 0 : 1)
            }
            .opacity(phase == .revealing ? 0 : 1)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .contentShape(.rect)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .light)
        .task { await animateLaunch() }
    }

    private var flash: some View {
        ZStack {
            Group {
                if let glassSnapshot {
                    Image(uiImage: glassSnapshot).resizable()
                } else {
                    Color.clear.glassEffect(.clear, in: FlashShape())
                }
            }
            .clipShape(FlashShape())
            TimelineView(.animation(minimumInterval: 1 / 30, paused: phase == .glass)) {
                timeline in
                let wavePhase = timeline.date.timeIntervalSinceReferenceDate * 1.6
                let gradient = LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black.opacity(0.96), location: 0.28),
                        .init(color: .black.opacity(0.55), location: 0.65),
                        .init(color: .black.opacity(0.08), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                ZStack {
                    ProgressFlashWater(progress: fill, phase: wavePhase, layer: .back)
                        .fill(gradient).opacity(0.45)
                    ProgressFlashWater(progress: fill, phase: wavePhase, layer: .front)
                        .fill(gradient)
                }
                .clipShape(FlashShape())
            }
            FlashShape().strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.7), .white.opacity(0.08), .white.opacity(0.4)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
    }

    private func animateLaunch() async {
        guard phase == .glass else { return }
        do {
            try await Task.sleep(for: .seconds(0.24))
            // Freeze only the empty glass surface; the water stays live during the finale.
            glassSnapshot = captureFlash()
            phase = .filling
            withAnimation(.linear(duration: 0.6), completionCriteria: .logicallyComplete) {
                fill = 2.0 / 3.0
            } completion: {
                withAnimation(.linear(duration: 0.3)) { fill = 1 }
                withAnimation(.easeIn(duration: 0.16), completionCriteria: .logicallyComplete) {
                    phase = .anticipating
                } completion: {
                    onReveal()
                    withAnimation(.easeOut(duration: 1.25), completionCriteria: .logicallyComplete)
                    {
                        phase = .revealing
                    } completion: {
                        onComplete()
                    }
                }
            }
        } catch {
            onComplete()
        }
    }
}

import SwiftUI

/// Connect the moving thought to the actual Flash contour, independent of device size.
struct IdentThoughtConnection {
    let contact: CGPoint
    let large: CGPoint
    let small: CGPoint
    let largeRadius: CGFloat
    let smallRadius: CGFloat

    init(tail: CGPoint, flash: CGRect) {
        let path = FlashShape().path(in: flash)
        let inside = CGPoint(
            x: flash.minX + flash.width * 0.55, y: flash.minY + flash.height * 0.53)
        let delta = CGVector(dx: inside.x - tail.x, dy: inside.y - tail.y)
        var lower: CGFloat = 0
        var upper: CGFloat = 1
        for _ in 0..<20 {
            let fraction = (lower + upper) / 2
            let point = CGPoint(x: tail.x + delta.dx * fraction, y: tail.y + delta.dy * fraction)
            if path.contains(point) { upper = fraction } else { lower = fraction }
        }
        contact = CGPoint(x: tail.x + delta.dx * upper, y: tail.y + delta.dy * upper)
        let distance = hypot(contact.x - tail.x, contact.y - tail.y)
        largeRadius = min(flash.width * 0.055, distance * 0.24)
        smallRadius = largeRadius * 0.48
        large = CGPoint(x: tail.x + largeRadius * 0.28, y: tail.y + largeRadius * 0.82)
        let divisor = max(0.001, distance)
        small = CGPoint(
            x: contact.x - (contact.x - tail.x) / divisor * smallRadius,
            y: contact.y - (contact.y - tail.y) / divisor * smallRadius)

    }
}

struct IdentThoughtView: View {
    let author: User
    let date: Date
    let text: String
    let size: CGSize
    let top: CGFloat
    let flash: CGRect
    let phase: IdentDetailPresentation.Phase
    let isClosing: Bool
    let onSelectUser: (User) -> Void
    @State private var bubbleSize = CGSize(width: 240, height: 88)
    @GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.45, bounce: 0.2)))
    private var drag: CGSize = .zero
    @State private var drift: CGSize = .zero

    var body: some View {
        let layout = IdentThoughtLayout(size: size, bubble: bubbleSize, top: top, flash: flash)
        let tail = CGPoint(
            x: layout.tail.x + drift.width + drag.width,
            y: layout.tail.y + drift.height + drag.height)
        let connection = IdentThoughtConnection(tail: tail, flash: flash)
        ZStack(alignment: .topLeading) {
            dot(radius: connection.smallRadius, at: connection.small, appearsAt: .smallDot)
            dot(radius: connection.largeRadius, at: connection.large, appearsAt: .largeDot)
            ViewThatFits(in: .horizontal) {
                bubble.fixedSize(horizontal: true, vertical: true)
                bubble.frame(width: size.width - 32)
            }
            .fixedSize(horizontal: false, vertical: true)
            .scaleEffect(phase >= .thought ? 1 : 0.72, anchor: .bottomLeading)
            .opacity(phase >= .thought ? 1 : 0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .updating($drag) { value, state, _ in
                        // value.translation contains distance (x,y)
                        state = IdentDetailGesture.resistedThoughtDrag(value.translation)
                    }
            )
            .offset(
                x: layout.origin.x + drift.width + drag.width,
                y: layout.origin.y + drift.height + drag.height)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .compositingGroup()
        .allowsHitTesting(phase >= .thought && !isClosing)
        .task(id: phase >= .thought && !isClosing) {
            guard phase >= .thought, !isClosing else { return }
            while !Task.isCancelled {
                let duration = Double.random(in: 2.8...4.0)
                withAnimation(.easeInOut(duration: duration)) {
                    drift = CGSize(width: .random(in: -16...16), height: .random(in: -12...12))
                }
                do { try await Task.sleep(for: .seconds(duration)) } catch { return }
            }
        }
    }

    private func dot(
        radius: CGFloat, at position: CGPoint, appearsAt phase: IdentDetailPresentation.Phase
    ) -> some View {
        Circle().fill(.clear)
            .frame(width: radius * 2, height: radius * 2)
            .glassEffect(.regular.tint(AppColor.background.opacity(0.18)), in: .circle)
            .scaleEffect(self.phase >= phase ? 1 : 0)
            .position(position)
            .allowsHitTesting(false)
    }

    private var bubble: some View {
        ViewThatFits(in: .vertical) {
            message.fixedSize(horizontal: false, vertical: true)
            ScrollView { message }.scrollBounceBehavior(.basedOnSize).frame(height: 150)
        }
        .frame(maxHeight: 150)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(
            .regular.tint(AppColor.background.opacity(0.18)), in: RoundedRectangle(cornerRadius: 48)
        )
        .clipShape(RoundedRectangle(cornerRadius: 48))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: {
            bubbleSize = $0
        }
    }

    private var message: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onSelectUser(author)
            } label: {
                UserAvatarView(image: RemoteImageReference(item: author.avatar))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Button(author.nickname) { onSelectUser(author) }
                        .font(.nunito(.caption).weight(.bold))
                        .buttonStyle(.plain)
                    Text(AppCalendar.shortDateAndTime(for: date))
                        .font(.nunito(.caption2))
                        .foregroundStyle(AppColor.muted)
                }
                Text(text.isEmpty ? "Ein neuer Ident." : text)
                    .font(.custom("Nunito-Bold", size: 16, relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(AppColor.text)
        .padding(.horizontal, 20).padding(.vertical, 20)
    }
}

struct IdentThoughtLayout {
    let size: CGSize
    let bubble: CGSize
    let top: CGFloat
    let flash: CGRect

    var origin: CGPoint {
        CGPoint(
            x: max(16, min(size.width - bubble.width - 16, flash.midX - bubble.width * 0.65)),
            y: max(top, flash.minY - bubble.height * 0.35))
    }

    var tail: CGPoint {
        CGPoint(x: origin.x + min(56, bubble.width * 0.26), y: origin.y + bubble.height - 2)
    }
}

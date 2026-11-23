import Kingfisher
import SwiftUI

/// A Flash with an optional photo and a colored contour softened toward its interior.
struct ImageFlash: View {
    let image: RemoteImageReference?
    let color: Color
    let usesGlassBorder: Bool

    init(image: RemoteImageReference? = nil, color: Color, usesGlassBorder: Bool = false) {
        self.image = image
        self.color = color
        self.usesGlassBorder = usesGlassBorder
    }

    /// Preserve the 54-point grid Flash as the reference size for the contour and its blur.
    static func outlineScale(for size: CGSize) -> CGFloat {
        min(size.width, size.height) / 54
    }

    static func glassBorderWidth(for size: CGSize) -> CGFloat {
        min(2, max(0.75, outlineScale(for: size) * 0.3))
    }

    var body: some View {
        GeometryReader { geometry in
            let outlineScale = Self.outlineScale(for: geometry.size)
            ZStack {
                FlashShape().fill(color)
                if let image {
                    KFImage(
                        source: .network(
                            KF.ImageResource(downloadURL: image.url, cacheKey: image.key))
                    )
                    .placeholder { ProgressView() }
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .overlay {
                FlashShape().stroke(color, lineWidth: 6 * outlineScale)
                    .blur(radius: 1.8 * outlineScale)
                if usesGlassBorder {
                    Color.clear.glassEffect(
                        .regular.tint(color.opacity(0.12)),
                        in: ImageFlashGlassBorder(width: Self.glassBorderWidth(for: geometry.size)))
                } else {
                    FlashShape().stroke(color, lineWidth: outlineScale)
                }
            }
            .clipShape(FlashShape())
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Apply glass only to the narrow contour, keeping the photograph clear.
private struct ImageFlashGlassBorder: Shape {
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        FlashShape().path(in: rect).subtracting(FlashShape().inset(by: width).path(in: rect))
    }
}

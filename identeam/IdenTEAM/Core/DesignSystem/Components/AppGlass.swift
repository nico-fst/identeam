import SwiftUI
import UIKit

/// Frosted surfaces, without Liquid Glass refraction or lens effects.
struct AppGlass: ViewModifier {
    let dark: Bool
    var tint: Color?
    var information = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
    }

    private var surfaceColors: [Color] {
        if let tint { return [tint.opacity(0.42), tint.opacity(0.18)] }
        if dark {
            return [
                AppColor.Glass.upper.opacity(0.62),
                AppColor.Glass.lower
                    .opacity(information ? 0.72 : 0.58),
            ]
        }
        return [
            AppColor.Palette.cream.opacity(information ? 0.32 : 0.52),
            AppColor.Palette.cream.opacity(information ? 0.14 : 0.46),
        ]
    }

    private var borderOpacity: Double { tint != nil ? 0.44 : dark ? 0.22 : 0.85 }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    AppBackdropBlur(dark: dark)
                        .allowsHitTesting(false)
                    shape.fill(
                        LinearGradient(
                            colors: surfaceColors, startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(borderOpacity), .white.opacity(borderOpacity * 0.45),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                // A second, inset highlight catches the upper edge, like the CSS inset shadow.
                shape.strokeBorder(.white.opacity(dark && tint == nil ? 0.14 : 0.44), lineWidth: 1)
                    .mask(alignment: .top) {
                        LinearGradient(
                            colors: [.white, .clear], startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 18)
                    }
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(dark && tint == nil ? 0.10 : 0.04), radius: 12, y: 8)
            .environment(\.colorScheme, dark ? .dark : .light)
            .foregroundStyle(dark ? AppColor.Palette.cream : AppColor.Palette.ink)
    }
}

/// Sample and soften the actual content behind every custom glass container.
/// Keep the effect view fully visible; only the separate color wash is translucent.
private struct AppBackdropBlur: UIViewRepresentable {
    let dark: Bool

    final class Coordinator {
        var dark: Bool
        init(dark: Bool) { self.dark = dark }
    }

    func makeCoordinator() -> Coordinator { Coordinator(dark: dark) }

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: effect)
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = 26
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        guard context.coordinator.dark != dark else { return }
        context.coordinator.dark = dark
        view.effect = effect
    }

    private var effect: UIBlurEffect {
        UIBlurEffect(style: dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
    }
}

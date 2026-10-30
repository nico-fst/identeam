import SwiftUI
import UIKit

/// Shared semantic colors for SwiftUI, UIKit and WidgetKit.
/// Semantic roles adapt to appearance; fixed palettes also support earned week stages.
enum AppColor {
    static let accent = Color.accentColor

    /// Fixed colors used when appearance is driven by content rather than device settings.
    enum Palette {
        static let cream = Color("PaletteCream")
        static let ink = Color("PaletteInk")
    }

    enum Member {
        static let colors: [Color] = [
            Color("MemberTerracotta"), Color("MemberViolet"),
            Color("MemberTeal"), Color("MemberRose"),
        ]

        static func color(at index: Int, dark: Bool) -> Color {
            let color = colors[index % colors.count]
            return dark ? color.mix(with: Palette.cream, by: 0.48) : color
        }
    }

    enum Motivation {
        static let lime = Color("MotivationLime")
        static let lavender = Color("MotivationLavender")
    }

    enum Glass {
        static let upper = Color("GlassUpperBrown")
        static let lower = Color("GlassLowerBrown")
    }

    enum Streak {
        static let flame = Color("StreakFlameGold")
        static let highlight = Color("StreakHighlightGold")
        static let glow = Color("StreakGlowGold")
        static let frozen = Color("StreakFrozenBlue")
    }

    static let background = Color("BackgroundAppCreamInk")
    static let surface = Color("BackgroundSurfaceApricotBrown")
    static let text = Color("TextPrimaryInkCream")
    static let muted = Color("TextSecondaryTaupeSand")
    static let link = Color("TextLinkBurntOrange")
    static let team = Color("StatusTeamViolet")
    static let streak = Color("StatusStreakOrangeGold")
    static let success = Color("StatusSuccessGreen")
    static let successSurface = Color("BackgroundSuccessSageBrown")
    static let error = Color("StatusErrorRed")
    static let onAccent = Color("TextOnAccentInk")
    static let onSuccess = Color("TextOnSuccessIvoryInk")
    static let cameraText = Color("CameraTextIvory")
    static let cameraShade = Color("CameraShadeInk")
    static let selection = Color("BackgroundSelectionPeachViolet")
}

extension View {
    func appColors() -> some View {
        self
            .foregroundStyle(AppColor.text)
            .tint(AppColor.link)
            .background(AppColor.background.ignoresSafeArea())
            .presentationBackground(AppColor.background)
    }

    func appListColors() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
    }
}

@MainActor
enum AppAppearance {
    static func configure(bundle: Bundle = .main) {
        func color(_ name: String) -> UIColor {
            guard let value = UIColor(named: name, in: bundle, compatibleWith: nil) else {
                preconditionFailure("Missing app color asset: \(name)")
            }
            return value
        }

        let background = color("BackgroundAppCreamInk")
        let surface = color("BackgroundSurfaceApricotBrown")
        let text = color("TextPrimaryInkCream")
        let muted = color("TextSecondaryTaupeSand")
        let link = color("TextLinkBurntOrange")

        UIView.appearance().tintColor = link
        UIWindow.appearance().backgroundColor = background
        UITableView.appearance().backgroundColor = background
        UITableView.appearance().separatorColor = muted.withAlphaComponent(0.2)
        UITableViewCell.appearance().backgroundColor = surface
        UICollectionView.appearance().backgroundColor = background
        UITextField.appearance().textColor = text
        UITextView.appearance().textColor = text
        UITextView.appearance().backgroundColor = surface

        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = background
        navigation.shadowColor = .clear
        navigation.shadowImage = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
            .image { _ in }
        navigation.titleTextAttributes = [
            .foregroundColor: text,
            .font: UIFontMetrics(forTextStyle: .headline).scaledFont(
                for: UIFont(name: "Nunito-Black", size: 17)!),
        ]
        navigation.largeTitleTextAttributes = [
            .foregroundColor: text,
            .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(
                for: UIFont(name: "Nunito-Black", size: 34)!),
        ]
        // An opaque scroll-edge background covers the expanded title on iOS 26+.
        // The page supplies the themed background; keep only the collapsed bar opaque.
        func scrollEdgeAppearance() -> UINavigationBarAppearance {
            let edge = UINavigationBarAppearance(barAppearance: navigation)
            edge.configureWithTransparentBackground()
            edge.titleTextAttributes = navigation.titleTextAttributes
            edge.largeTitleTextAttributes = navigation.largeTitleTextAttributes
            edge.shadowColor = .clear
            edge.shadowImage = navigation.shadowImage
            return edge
        }
        UINavigationBar.appearance().titleTextAttributes = navigation.titleTextAttributes
        UINavigationBar.appearance().largeTitleTextAttributes = navigation.largeTitleTextAttributes
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeAppearance()
        UINavigationBar.appearance().compactAppearance = navigation

        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = background
        for items in [
            tabs.stackedLayoutAppearance, tabs.inlineLayoutAppearance,
            tabs.compactInlineLayoutAppearance,
        ] {
            items.normal.titleTextAttributes = [.foregroundColor: muted]
            items.normal.iconColor = muted
            items.selected.titleTextAttributes = [.foregroundColor: link]
            items.selected.iconColor = link
        }
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs

        UISwitch.appearance().thumbTintColor = background
        UISwitch.appearance().onTintColor = link
        UISwitch.appearance().tintColor = color("BackgroundSelectionPeachViolet")

        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.foregroundColor: text], for: .normal)
        for button in [navigation.buttonAppearance, navigation.backButtonAppearance] {
            button.normal.titleTextAttributes = [.foregroundColor: text]
        }
        navigation.doneButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: color("TextOnAccentInk")
        ]
        // Appearance values are copied into the bar; apply the updated button colors too.
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeAppearance()
        UINavigationBar.appearance().compactAppearance = navigation

        UISegmentedControl.appearance().backgroundColor = background
        UISegmentedControl.appearance().selectedSegmentTintColor = color(
            "BackgroundSelectionPeachViolet")
        for state: UIControl.State in [.normal, .selected] {
            UISegmentedControl.appearance().setTitleTextAttributes(
                [.foregroundColor: text], for: state)
        }
    }
}

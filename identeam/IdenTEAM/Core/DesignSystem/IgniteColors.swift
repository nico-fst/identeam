import SwiftUI
import UIKit

/// Shared Ignite colors for the app and WidgetKit, resolved for light and dark appearances.
enum IgniteColor {
    static let background = Color("IgniteBackground")
    static let surface = Color("IgniteSurface")
    static let text = Color("IgniteText")
    static let muted = Color("IgniteMuted")
    static let link = Color("IgniteLink")
    static let team = Color("IgniteTeam")
    static let streak = Color("IgniteStreak")
    static let success = Color("IgniteSuccess")
    static let successSurface = Color("IgniteSuccessSurface")
    static let error = Color("ErrorColor")
    static let onAccent = Color("IgniteOnAccent")
    static let onSuccess = Color("IgniteOnSuccess")
    static let cameraText = Color("IgniteCameraText")
    static let cameraShade = Color("IgniteCameraShade")
    static let selection = Color("IgniteSelection")
}

extension View {
    func igniteColors() -> some View {
        self
            .foregroundStyle(IgniteColor.text)
            .tint(IgniteColor.link)
            .background(IgniteColor.background.ignoresSafeArea())
            .presentationBackground(IgniteColor.background)
    }

    func igniteListColors() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(IgniteColor.background)
    }
}

@MainActor
enum IgniteAppearance {
    static func configure(bundle: Bundle = .main) {
        func color(_ name: String) -> UIColor {
            guard let value = UIColor(named: name, in: bundle, compatibleWith: nil) else {
                preconditionFailure("Missing Ignite color asset: \(name)")
            }
            return value
        }

        let background = color("IgniteBackground")
        let surface = color("IgniteSurface")
        let text = color("IgniteText")
        let muted = color("IgniteMuted")
        let link = color("IgniteLink")

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
        // The page supplies the Ignite fill; keep only the collapsed bar opaque.
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
        UISwitch.appearance().tintColor = color("IgniteSelection")

        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.foregroundColor: text], for: .normal)
        for button in [navigation.buttonAppearance, navigation.backButtonAppearance] {
            button.normal.titleTextAttributes = [.foregroundColor: text]
        }
        navigation.doneButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: color("IgniteOnAccent")
        ]
        // Appearance values are copied into the bar; apply the updated button colors too.
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeAppearance()
        UINavigationBar.appearance().compactAppearance = navigation

        UISegmentedControl.appearance().backgroundColor = background
        UISegmentedControl.appearance().selectedSegmentTintColor = color("IgniteSelection")
        for state: UIControl.State in [.normal, .selected] {
            UISegmentedControl.appearance().setTitleTextAttributes(
                [.foregroundColor: text], for: state)
        }
    }
}

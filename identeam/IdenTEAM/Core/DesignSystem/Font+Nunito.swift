import SwiftUI

extension Font {
    /// Accent typography only. Ordinary body text keeps the system font.
    static func nunito(_ style: Font.TextStyle) -> Font {
        let size: CGFloat
        let name: String
        switch style {
        case .largeTitle: (size, name) = (34, "Nunito-Black")
        case .title: (size, name) = (28, "Nunito-Black")
        case .title2: (size, name) = (22, "Nunito-Black")
        case .title3: (size, name) = (20, "Nunito-Black")
        case .headline: (size, name) = (17, "Nunito-Black")
        case .subheadline: (size, name) = (15, "Nunito-SemiBold")
        case .footnote: (size, name) = (13, "Nunito-SemiBold")
        case .caption: (size, name) = (12, "Nunito-SemiBold")
        case .caption2: (size, name) = (11, "Nunito-SemiBold")
        default: return .system(style)
        }
        return .custom(name, size: size, relativeTo: style)
    }
}

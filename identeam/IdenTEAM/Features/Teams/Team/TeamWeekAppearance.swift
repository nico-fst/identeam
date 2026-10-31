import CoreText
import SwiftUI

/// The weekly experience has its own earned light/dark stages, independent of device appearance.
enum TeamWeekStyle {
    static func font(_ size: CGFloat, heavy: Bool = false) -> Font {
        .custom(heavy ? "Nunito-Black" : "Nunito-Bold", size: size, relativeTo: .body)
    }
    static func color(for member: String, in week: TeamWeekPresentation, dark: Bool? = nil) -> Color
    {
        let index = week.members.map(\.id).sorted().firstIndex(of: member) ?? 0
        return AppColor.Member.color(at: index, dark: dark ?? week.darkWeek)
    }
}

/// Move only the diagonal edge; keep the full-screen background and safe area anchored.
struct TeamWeekScrollingBackdrop: ViewModifier {
    let stage: Int
    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrollOffset = offset
            }
            .background {
                DiagonalDarkCutBackrop(stage: stage, scrollOffset: scrollOffset)
                    .ignoresSafeArea()
                    .transaction { $0.animation = nil }
            }
            .background(
                (stage >= 4 ? AppColor.Palette.ink : AppColor.Palette.cream).ignoresSafeArea())
    }
}

struct DiagonalDarkCutBackrop: View {
    let stage: Int
    var scrollOffset: CGFloat = 0
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                AppColor.Palette.cream
                Path { path in
                    let vertices = TeamWeekBackdropGeometry.vertices(
                        stage: stage, size: geometry.size, scrollOffset: scrollOffset)
                    guard let first = vertices.first else { return }
                    path.move(to: first)
                    for point in vertices.dropFirst() { path.addLine(to: point) }
                    path.closeSubpath()
                }
                .fill(AppColor.Palette.ink)

            }
        }
        .allowsHitTesting(false)
    }
}

struct TeamWeekAuraLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Locked in?").font(TeamWeekStyle.font(19, heavy: true))
            Text(
                """
                Je mehr Idents ihr gemeinsam für euer Wochenziel sammelt, \
                desto stärker hüllt schwarze Aura den Bildschirm ein.
                """)
            Text("Der Dark Cut zeigt: Euer Team zieht durch. Ihr seid locked in.")
        }
        .font(TeamWeekStyle.font(14))
        .frame(width: 280)
    }
}

extension TeamWeekPresentation {
    init(week: TeamWeek, currentUserID: String, now: Date = .now) {
        self.init(
            weekStart: AppCalendar.startOfWeek(containing: week.weekStart),
            members: week.members.map { member in
                Member(
                    id: member.user.userID, name: member.user.nickname,
                    targets: member.targetDays,
                    idents: member.idents.map { Entry(id: Self.identID($0), time: $0.time) })
            }.sorted { $0.id < $1.id },
            currentUserID: currentUserID, streak: Int(week.teamStreak),
            now: now)
    }

    static func identID(_ ident: Ident) -> String {
        ident.remoteID != 0 ? String(ident.remoteID) : String(describing: ident.id)
    }
}

/// Uses the variable font's maximum weight, beyond its named Black instance.
struct TeamWeekHeavyText: ViewModifier {
    private let size: CGFloat

    init(_ size: CGFloat) {
        self.size = size
    }

    func body(content: Content) -> some View {
        let descriptor = CTFontDescriptorCreateWithAttributes(
            [
                kCTFontNameAttribute: "Nunito-Black",
                kCTFontVariationAttribute: [0x7767_6874: 1000],  // OpenType wght axis.
            ] as CFDictionary)
        content.font(Font(CTFontCreateWithFontDescriptor(descriptor, size, nil)))
    }
}

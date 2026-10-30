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

struct TeamWeekStreakIcon: View {
    let streak: Int
    var showsGlow = true
    private var flames: TeamWeekStreakFlames { TeamWeekStreakFlames(streak: streak) }

    var body: some View {
        ZStack {
            if streak == 0 {
                Image(systemName: "snowflake")
                    .font(.system(size: 54, weight: .heavy))
                    .foregroundStyle(AppColor.Streak.frozen)
            } else {
                if flames.showsLarge {
                    Image("StreakFlame")
                        .resizable().scaledToFit()
                        .frame(width: 72, height: 84)
                        .foregroundStyle(AppColor.Streak.flame)
                }
                if flames.showsSmall {
                    Image("StreakFlame")
                        .resizable().scaledToFit()
                        .frame(width: 72, height: 84)
                        .foregroundStyle(AppColor.Streak.highlight)
                        .scaleEffect(0.72, anchor: UnitPoint(x: 0.5, y: 0.65))
                        .offset(x: 3, y: 9)
                }
                Text("\(streak)")
                    .font(TeamWeekStyle.font(26, heavy: true))
                    .foregroundStyle(AppColor.Palette.ink)
                    .offset(x: flames.showsSmall ? 3 : 0, y: flames.showsSmall ? 24 : 15)
            }
        }
        .frame(width: 72, height: 84)
        .background {
            if showsGlow {
                Circle()
                    .fill(
                        streak == 0
                            ? AppColor.Streak.frozen.opacity(0.30)
                            : AppColor.Streak.glow.opacity(
                                0.48 * TeamWeekStreakGlow.strength(for: streak))
                    )
                    .frame(width: streak == 0 ? 130 : 190, height: streak == 0 ? 130 : 190)
                    .blur(radius: streak == 0 ? 55 : 45)
            }
        }
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

struct TeamWeekStreakInfoButton: View {
    let streak: Int
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            TeamWeekStreakIcon(streak: streak)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            TeamWeekStreakLegend().padding(20).presentationCompactAdaptation(.popover)
        }
    }
}

struct TeamWeekStreakLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Eure Team-Streak").font(TeamWeekStyle.font(19, heavy: true))
            HStack(alignment: .top, spacing: 8) {
                ForEach(0...3, id: \.self) { streak in
                    VStack(spacing: 6) {
                        TeamWeekStreakIcon(streak: streak, showsGlow: false)
                            .scaleEffect(0.65).frame(width: 60, height: 60)
                        Text(["Keine", "1 Woche", "2 Wochen", "Ab 3 Wochen"][streak])
                            .font(TeamWeekStyle.font(11, heavy: true))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(
                """
                Erreicht euer Team in einer Woche mindestens die Summe aller persönlichen Wochenziele, \
                wächst eure Streak um 1.
                """)
            Text(
                "Beispiel: Eure Ziele sind 3, 2 und 4 Idents. Zusammen braucht ihr 9 Idents – egal, wer sie macht."
            )
            Text(
                "Verfehlt ihr das gemeinsame Wochenziel, verliert ihr eure Streak und startet wieder bei 0."
            )
        }
        .font(TeamWeekStyle.font(14))
        .frame(width: 300)
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

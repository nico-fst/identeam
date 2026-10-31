import SwiftUI

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

#if DEBUG
    private struct StreakDarkCutPreview: View {
        let streak: Int
        var body: some View {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0...4, id: \.self) { stage in
                        HStack {
                            Text("Dark Cut \(stage)").font(TeamWeekStyle.font(14, heavy: true))
                            Spacer()
                            TeamWeekStreakInfoButton(streak: streak)
                        }
                        .padding(24)
                        .frame(height: 160)
                        .foregroundStyle(stage >= 2 ? AppColor.Palette.cream : AppColor.Palette.ink)
                        .background(DiagonalDarkCutBackrop(stage: stage))
                        .clipped()
                        .environment(\.colorScheme, stage >= 2 ? .dark : .light)
                    }
                }
            }
            .frame(width: 390)
        }
    }
    #Preview("Streak · 0") { StreakDarkCutPreview(streak: 0) }
    #Preview("Streak · 1") { StreakDarkCutPreview(streak: 1) }
    #Preview("Streak · 2") { StreakDarkCutPreview(streak: 2) }
    #Preview("Streak · 3+") { StreakDarkCutPreview(streak: 3) }
#endif

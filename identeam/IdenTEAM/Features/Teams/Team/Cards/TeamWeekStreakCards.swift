import SwiftUI

/// Streak card family appended after the optional primary card by `TeamWeekPresentation.summaryCards`.
/// TeamWeekSummaryCards dispatches each variant here. Unlike the message-based families, these variants
/// supply their own layouts directly to TeamWeekCard while sharing its dimensions, alignment and glass surface.
struct TeamWeekStreakCard: View {
    let kind: TeamWeekSummaryCard.Streak
    let week: TeamWeekPresentation
    let dark: Bool

    var body: some View {
        TeamWeekCard(dark: dark) {
            VStack(alignment: .center, spacing: 15) {
                switch kind {
                case .flame:
                    Text(week.streak == 0 ? "EUER ERSTES FEUER WARTET." : "EUER FEUER BRENNT.")
                        .font(TeamWeekStyle.font(11, heavy: true)).tracking(1.3)
                    TeamWeekStreakIcon(streak: week.streak).scaleEffect(1.2).padding(.vertical, 10)
                    Text(
                        week.streak == 0
                            ? "Entfacht euer Feuer." : "\(week.streak) Wochen.\nUnaufhaltsam."
                    )
                    .font(TeamWeekStyle.font(30, heavy: true)).multilineTextAlignment(.center)
                    Text("Gemeinsam das Wochenziel schaffen. Jede Woche zählt.")
                        .multilineTextAlignment(.center)
                case .level:
                    HStack {
                        VStack(alignment: .center) {
                            Text("STREAK LEVEL").font(TeamWeekStyle.font(11, heavy: true)).tracking(
                                1.3)
                            Text(String(format: "%02d", week.streak)).font(
                                TeamWeekStyle.font(62, heavy: true))
                        }
                        TeamWeekStreakIcon(streak: week.streak)
                    }
                    Text("Ihr seid on fire.").font(TeamWeekStyle.font(29, heavy: true))
                    ProgressView(value: Double(week.streak), total: Double(nextMilestone)).tint(
                        AppColor.Streak.glow)
                    Text("\(week.streak) / \(nextMilestone) Wochen bis zum Meilenstein")
                case .chain:
                    HStack {
                        TeamWeekStreakIcon(streak: week.streak)
                        Text("Jede Woche ein Link.").font(TeamWeekStyle.font(12, heavy: true))
                    }
                    Text("Die Kette hält.").font(TeamWeekStyle.font(29, heavy: true))
                    Text("\(week.streak) Wochen zusammen drangeblieben.")
                    HStack(spacing: 8) {
                        ForEach(0..<min(5, week.streak + 1), id: \.self) { index in
                            VStack(spacing: 5) {
                                Image(systemName: index < week.streak ? "checkmark" : "flame")
                                    .font(.system(size: 17, weight: .black))
                                    .frame(width: 34, height: 34)
                                    .background(
                                        AppColor.Streak.glow.opacity(
                                            index < week.streak ? 0.85 : 0.16),
                                        in: .circle)
                                Text("Woche \(index + 1)").font(TeamWeekStyle.font(9))
                            }
                        }
                    }
                case .milestone:
                    ZStack {
                        Image(systemName: "medal.fill").font(.system(size: 110)).foregroundStyle(
                            AppColor.Streak.glow.opacity(0.35))
                        TeamWeekStreakIcon(streak: week.streak)
                    }.frame(maxWidth: .infinity).padding(.vertical, 10)
                    Text(
                        week.streak == 0 ? "DEIN ERSTER MEILENSTEIN WARTET" : "MEILENSTEIN ERREICHT"
                    )
                    .font(TeamWeekStyle.font(11, heavy: true)).tracking(1)
                    Text(
                        week.streak == 0
                            ? "Der Anfang zählt."
                            : week.streak == 1
                                ? "Der Anfang steht."
                                : week.streak == 2 ? "Doppelt stark." : "Ein starkes Team."
                    )
                    .font(TeamWeekStyle.font(29, heavy: true))
                    Text("\(week.streak) Wochen Streak. Das habt ihr euch verdient.")
                }
            }
            .font(TeamWeekStyle.font(14))
        }
    }

    private var nextMilestone: Int { (week.streak / 5 + 1) * 5 }
}

#if DEBUG
    private struct StreakCardsPreview: View {
        let dark: Bool
        var body: some View {
            TeamWeekCardsPreview(dark: dark) {
                ForEach(TeamWeekSummaryCard.Streak.allCases, id: \.self) { kind in
                    TeamWeekStreakCard(kind: kind, week: TeamWeekPreviewFixtures.make(), dark: dark)
                }
            }
        }
    }
    #Preview("Streak · Hell") { StreakCardsPreview(dark: false) }
    #Preview("Streak · Dark Cut") { StreakCardsPreview(dark: true) }
#endif

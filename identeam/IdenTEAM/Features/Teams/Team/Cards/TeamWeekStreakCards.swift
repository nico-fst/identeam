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
            VStack(alignment: .center, spacing: 0) {
                switch kind {
                case .flame:
                    Text(week.streak == 0 ? "EUER ERSTES FEUER WARTET." : "EUER FEUER BRENNT.")
                        .font(TeamWeekStyle.font(14, heavy: true)).tracking(1.3)
                    Spacer(minLength: 4)
                    TeamWeekStreakIcon(streak: week.streak).scaleEffect(0.9).frame(
                        width: 65, height: 76)
                    Spacer(minLength: 4)
                    Text(
                        week.streak == 0
                            ? "Entfacht euer Feuer." : "\(week.streak) Wochen.\nUnaufhaltsam."
                    )
                    .font(TeamWeekStyle.font(32, heavy: true)).multilineTextAlignment(.center)
                    Spacer(minLength: 4)
                    Text("Gemeinsam das Wochenziel schaffen. Jede Woche zählt.")
                        .multilineTextAlignment(.center)
                case .level:
                    HStack {
                        VStack(alignment: .center) {
                            Text("STREAK LEVEL").font(TeamWeekStyle.font(14, heavy: true)).tracking(
                                1.3)
                            Text(String(format: "%02d", week.streak)).font(
                                TeamWeekStyle.font(48, heavy: true))
                        }
                        TeamWeekStreakIcon(streak: week.streak).scaleEffect(0.75).frame(
                            width: 54, height: 64)
                    }
                    Spacer(minLength: 4)
                    Text("Ihr seid on fire.").font(TeamWeekStyle.font(32, heavy: true))
                    Spacer(minLength: 4)
                    ProgressView(value: Double(week.streak), total: Double(nextMilestone)).tint(
                        AppColor.Streak.glow)
                    Spacer(minLength: 4)
                    Text("\(week.streak) / \(nextMilestone) Wochen bis zum Meilenstein")
                case .chain:
                    HStack {
                        TeamWeekStreakIcon(streak: week.streak).scaleEffect(0.75).frame(
                            width: 54, height: 64)
                        Text("Jede Woche ein Link.").font(TeamWeekStyle.font(14, heavy: true))
                    }
                    Spacer(minLength: 4)
                    Text("Die Kette hält.").font(TeamWeekStyle.font(32, heavy: true))
                    Spacer(minLength: 4)
                    Text("\(week.streak) Wochen zusammen drangeblieben.")
                    Spacer(minLength: 4)
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
                                Text("Woche \(index + 1)").font(TeamWeekStyle.font(11))
                            }
                        }
                    }
                case .milestone:
                    ZStack {
                        Image(systemName: "medal.fill").font(.system(size: 80)).foregroundStyle(
                            AppColor.Streak.glow.opacity(0.35))
                        TeamWeekStreakIcon(streak: week.streak).scaleEffect(0.9).frame(
                            width: 65, height: 76)
                    }.frame(maxWidth: .infinity).frame(height: 82)
                    Spacer(minLength: 4)
                    Text(
                        week.streak == 0 ? "DEIN ERSTER MEILENSTEIN WARTET" : "MEILENSTEIN ERREICHT"
                    )
                    .font(TeamWeekStyle.font(14, heavy: true)).tracking(1)
                    Spacer(minLength: 4)
                    Text(
                        week.streak == 0
                            ? "Der Anfang zählt."
                            : week.streak == 1
                                ? "Der Anfang steht."
                                : week.streak == 2 ? "Doppelt stark." : "Ein starkes Team."
                    )
                    .font(TeamWeekStyle.font(32, heavy: true))
                    Spacer(minLength: 4)
                    Text("\(week.streak) Wochen Streak. Das habt ihr euch verdient.")
                }
            }
            .font(TeamWeekStyle.font(16))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

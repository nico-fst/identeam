import SwiftUI

/// Strongly tinted card family dispatched by TeamWeekSummaryCards from the selected card identity.
/// Supplies copy and tint to TeamWeekMessageCard, and explicitly chooses TeamWeekTeamProgress or TeamWeekMemberRanking.
struct TeamWeekAggressiveCard: View {
    let kind: TeamWeekSummaryCard.Aggressive
    let week: TeamWeekPresentation
    let dark: Bool

    private var tint: Color {
        switch kind {
        case .nearlyFinished: AppColor.accent
        case .behind: AppColor.Motivation.lime
        case .catchingUp: AppColor.Motivation.lavender
        }
    }

    private var copy: TeamWeekCardCopy {
        switch kind {
        case .nearlyFinished:
            TeamWeekCardCopy(
                "So nah dran", "1 Noch. Fritten in die Tüte jetzt!",
                "\(week.completed) von \(week.target) Male habt ihr schon durchgezogen. "
                    + "Peinlich, wenn das jetzt so kurz vorm Ziel eine Antiklimax wird.")
        case .behind:
            TeamWeekCardCopy(
                "Peinlichrrrr \(week.currentMember?.name ?? "Team")", "Starte jetzt ein Comeback!",
                "Deswegen wurdest du bei deinem letzten Job-Interview abgelehnt. "
                    + "Zieh jetzt endlich mal durch. Von nichts kommt nichts...")
        case .catchingUp:
            TeamWeekCardCopy(
                "Opfer? L", "Dein Team zieht durch (du nicht).",
                "Die anderen sind schon fast fertig. Dir fehlen noch \(week.currentMember?.remaining ?? 0) Idents. "
                    + "Dein nächster zählt.")
        }
    }

    var body: some View {
        TeamWeekMessageCard(
            copy: copy, dark: dark, tint: tint,
            watermark: kind == .catchingUp ? .letter("L", opacity: 0.075) : .flash(opacity: 0.075),
            titleSize: 34
        ) {
            if kind == .catchingUp {
                TeamWeekMemberRanking(week: week, dark: dark)
            } else {
                TeamWeekTeamProgress(
                    week: week, dark: dark, showsRemaining: kind == .nearlyFinished)
            }
        }
    }
}

#if DEBUG
    private struct AggressiveCardsPreview: View {
        let dark: Bool
        var body: some View {
            TeamWeekCardsPreview(dark: dark) {
                ForEach(TeamWeekSummaryCard.Aggressive.allCases, id: \.self) { kind in
                    TeamWeekAggressiveCard(
                        kind: kind, week: TeamWeekPreviewFixtures.make(card: .aggressive(kind)),
                        dark: dark)
                }
            }
        }
    }
    #Preview("Aggressive · Hell") { AggressiveCardsPreview(dark: false) }
    #Preview("Aggressive · Dark Cut") { AggressiveCardsPreview(dark: true) }
#endif

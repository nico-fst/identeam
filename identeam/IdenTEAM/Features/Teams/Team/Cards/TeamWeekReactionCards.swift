import SwiftUI

/// Feedback card family dispatched by TeamWeekSummaryCards for recaps, new weeks and today's Ident reactions.
/// Reuses TeamWeekMessageCard for copy and TeamWeekMemberProgress or TeamWeekTeamProgress for details.
struct TeamWeekReactionCard: View {
    let kind: TeamWeekSummaryCard.Reaction
    let week: TeamWeekPresentation
    let dark: Bool

    private var copy: TeamWeekCardCopy {
        switch kind {
        case .recap:
            TeamWeekCardCopy(
                "Woche im Rückblick",
                week.remaining == 0 && week.target > 0
                    ? "Gemeinsam durchgezogen." : "Jeder Ident zählt.",
                "\(week.completed) von \(week.target) Idents. Neue Woche, neue Chance.")
        case .newWeek:
            TeamWeekCardCopy(
                "Neue Woche. Abfahrt.", "Fetzt du den 1. Ident diese Woche?",
                "Setzt du dir nur Ziele, oder bist du ein Macher?")
        case .personallyOnTrack:
            TeamWeekCardCopy(
                "Macher", "Du bist auf Kurs!",
                "Geil, dass du durchziehst, ehrlich! Du darfst einmal dabben, ohne dabei Aura zu verlieren."
            )
        case .teamOnTrack:
            TeamWeekCardCopy(
                "Macher Team <3", "Dein Team ist auf Kurs.",
                week.remaining == 0
                    ? "Wochenziel erreicht. Zusammen. Weiter."
                    : "Ihr zieht gemeinsam durch. Eure nächsten Termine stehen.")
        }
    }

    var body: some View {
        TeamWeekMessageCard(
            copy: copy, dark: dark,
            watermark: [.personallyOnTrack, .teamOnTrack].contains(kind) ? .letter("W") : .flash()
        ) {
            if [.newWeek, .personallyOnTrack].contains(kind) {
                TeamWeekMemberProgress(
                    week: week, dark: dark, highlightsViewer: kind == .personallyOnTrack)
            } else {
                TeamWeekTeamProgress(week: week, dark: dark)
            }
        }
    }
}

#if DEBUG
    private struct ReactionCardsPreview: View {
        let dark: Bool
        var body: some View {
            TeamWeekCardsPreview(dark: dark) {
                ForEach(TeamWeekSummaryCard.Reaction.allCases, id: \.self) { kind in
                    TeamWeekReactionCard(
                        kind: kind, week: TeamWeekPreviewFixtures.make(card: .reaction(kind)),
                        dark: dark)
                }
            }
        }
    }
    #Preview("Reaction · Hell") { ReactionCardsPreview(dark: false) }
    #Preview("Reaction · Dark Cut") { ReactionCardsPreview(dark: true) }
#endif

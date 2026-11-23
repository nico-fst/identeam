import SwiftUI

/// Interactive card family selected by `TeamWeekPresentation.summaryCards` and rendered by TeamWeekSummaryCards.
/// Composes TeamWeekMessageCard with copy and a button; the goal action is passed down from the screen.
struct TeamWeekActionCard: View {
    let kind: TeamWeekSummaryCard.Action
    let week: TeamWeekPresentation
    let dark: Bool
    let setGoal: () -> Void

    private var goalIsForNextWeek: Bool {
        !TargetPlanning.canSetTargetWeek(week.weekStart, now: week.now)
    }

    var body: some View {
        switch kind {
        case .setGoal:
            TeamWeekMessageCard(
                copy: TeamWeekCardCopy(
                    "Nicht planlos durchs Leben", "Her mit deinem Ziel!",
                    goalIsForNextWeek
                        ? "Die Planung für diese Woche ist geschlossen. Leg jetzt dein Ziel für nächste Woche fest."
                        : "Setz dir ein Wochenziel und mach den ersten Schritt. Dein Team wartet auf dich."
                ),
                dark: dark
            ) {
                Button(
                    goalIsForNextWeek ? "Ziel für nächste Woche setzen" : "Wochenziel setzen",
                    action: setGoal
                )
                .font(TeamWeekStyle.font(16, heavy: true))
                .buttonStyle(.glassProminent).tint(AppColor.accent)
            }
        }
    }
}

#if DEBUG
    private struct ActionCardsPreview: View {
        let dark: Bool
        var body: some View {
            TeamWeekCardsPreview(dark: dark) {
                ForEach(TeamWeekSummaryCard.Action.allCases, id: \.self) { kind in
                    TeamWeekActionCard(
                        kind: kind, week: TeamWeekPreviewFixtures.make(card: .action(kind)),
                        dark: dark, setGoal: {})
                }
            }
        }
    }
    #Preview("Action · Hell") { ActionCardsPreview(dark: false) }
    #Preview("Action · Dark Cut") { ActionCardsPreview(dark: true) }
#endif

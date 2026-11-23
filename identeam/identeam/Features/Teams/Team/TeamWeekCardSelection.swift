import Foundation

/// Card identity is independent of its position in the carousel.
/// `TeamWeekPresentation.summaryCards` selects and orders these values; TeamWeekSummaryCards dispatches
/// each family and variant to its matching view. This type describes content without owning its layout.
nonisolated enum TeamWeekSummaryCard: Hashable, Identifiable {
    enum Action: CaseIterable, Hashable { case setGoal }
    enum Aggressive: CaseIterable, Hashable { case nearlyFinished, behind, catchingUp }
    enum Reaction: CaseIterable, Hashable { case recap, newWeek, personallyOnTrack, teamOnTrack }
    enum Streak: CaseIterable, Hashable { case flame, level, chain, milestone }

    case action(Action)
    case aggressive(Aggressive)
    case reaction(Reaction)
    case streak(Streak)

    var id: Self { self }

    var isAggressive: Bool {
        if case .aggressive = self { return true }
        return false
    }
}

extension TeamWeekPresentation {
    /// Selection pseudocode (first matching condition wins):
    ///
    /// IF selected week is past: primary = reaction.recap
    /// ELSE IF viewer idented today in the current week:
    ///     IF viewer is unfinished AND ahead of someone (or trains alone): primary = reaction.personallyOnTrack
    ///     ELSE: primary = reaction.teamOnTrack
    /// ELSE IF personal target is unset: primary = action.setGoal
    /// ELSE IF team has no Idents: primary = reaction.newWeek
    /// ELSE IF team needs exactly one Ident: primary = aggressive.nearlyFinished
    /// ELSE IF viewer needs Idents AND all other planned members are ahead and need <= 1:
    ///     primary = aggressive.catchingUp
    /// ELSE IF a scheduled day was missed AND team target is incomplete: primary = aggressive.behind
    /// ELSE: no primary card
    /// RETURN [primary if present, streak.flame, streak.level, streak.chain, streak.milestone]
    ///
    /// Selection returns the card identity directly; rendering never re-evaluates these rules.
    nonisolated var primarySummaryCard: TeamWeekSummaryCard? {
        if isPast { return .reaction(.recap) }
        if viewerIdentedToday, let currentMember {
            let others = members.filter { $0.id != currentUserID && $0.target > 0 }
            if currentMember.remaining > 0,
                others.isEmpty || others.contains(where: { $0.progress < currentMember.progress })
            {
                return .reaction(.personallyOnTrack)
            }
            return .reaction(.teamOnTrack)
        }
        if let currentMember, currentMember.target == 0 { return .action(.setGoal) }
        if completed == 0 { return .reaction(.newWeek) }
        if target > 0, remaining == 1 { return .aggressive(.nearlyFinished) }
        if let currentMember, currentMember.remaining > 0 {
            let others = members.filter { $0.id != currentUserID && $0.target > 0 }
            if !others.isEmpty, others.allSatisfy({ $0.remaining <= 1 }),
                others.allSatisfy({ $0.progress > currentMember.progress })
            {
                return .aggressive(.catchingUp)
            }
        }
        if marks.contains(where: { $0.kind == .missed }), remaining > 0 {
            return .aggressive(.behind)
        }
        return nil
    }

    /// The optional primary card precedes the four streak variants in both pager and stacked previews.
    nonisolated var summaryCards: [TeamWeekSummaryCard] {
        [primarySummaryCard].compactMap { $0 }
            + TeamWeekSummaryCard.Streak.allCases.map(TeamWeekSummaryCard.streak)
    }
}

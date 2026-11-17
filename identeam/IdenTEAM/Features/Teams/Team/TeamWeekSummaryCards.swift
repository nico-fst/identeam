import SwiftUI

/// Container for the ordered identities from `TeamWeekPresentation.summaryCards` (TeamWeekCardSelection.swift).
/// Dispatches each identity to Action, Aggressive, Reaction or Streak; the families compose TeamWeekCard.
/// Owns horizontal paging and the page indicator in the app, or stacks the same selection in screen previews.
/// Selection rules and individual card layouts remain with the presentation and card families respectively.
struct TeamWeekSummaryCards: View {
    let week: TeamWeekPresentation
    var stacked = false
    var onSelectMember: (String) -> Void = { _ in }
    let setGoal: () -> Void
    @State private var page: Int? = 0

    var body: some View {
        let cards = Array(week.summaryCards.enumerated())
        if stacked {
            VStack(spacing: 16) {
                ForEach(week.summaryCards) { card in cardView(card) }
            }
        } else {
            VStack(spacing: 10) {
                GeometryReader { geometry in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(cards, id: \.element.id) { index, card in
                                cardView(card)
                                    .frame(width: geometry.size.width)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $page)
                }
                .aspectRatio(TeamWeekCardLayout.aspectRatio, contentMode: .fit)
                pageIndicator
            }
            .onChange(of: week.summaryCards) {
                page = min(page ?? 0, week.summaryCards.count - 1)
            }
        }
    }

    @ViewBuilder private func cardView(_ card: TeamWeekSummaryCard) -> some View {
        switch card {
        case .action(let kind):
            TeamWeekActionCard(kind: kind, week: week, dark: week.darkInfo, setGoal: setGoal)
        case .aggressive(let kind):
            TeamWeekAggressiveCard(
                kind: kind, week: week, dark: week.darkInfo, onSelectMember: onSelectMember)
        case .reaction(let kind):
            TeamWeekReactionCard(
                kind: kind, week: week, dark: week.darkInfo, onSelectMember: onSelectMember)
        case .streak(let kind):
            TeamWeekStreakCard(kind: kind, week: week, dark: week.darkStreak)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(week.summaryCards.indices, id: \.self) { index in
                Button {
                    withAnimation(.smooth) { page = index }
                } label: {
                    Capsule().fill(
                        (week.darkWeek ? AppColor.Palette.cream : AppColor.Palette.ink)
                            .opacity(page == index ? 1 : 0.28)
                    )
                    .frame(width: page == index ? 13 : 4, height: 4)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Karte \(index + 1) von \(week.summaryCards.count)")
                .accessibilityAddTraits(page == index ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .modifier(AppGlass(dark: week.darkWeek))
    }
}

import SwiftUI

/// Shared dimensions for TeamWeekCard and the paging viewport in TeamWeekSummaryCards.
enum TeamWeekCardLayout {
    static let aspectRatio: CGFloat = 6 / 5
    static let referenceSize = CGSize(width: 360, height: 300)
}

/// Explicit decoration shared by message cards; streak cards use no watermark.
enum TeamWeekCardWatermark {
    case none
    case flash(opacity: Double = 0.045)
    case letter(String, opacity: Double = 0.045)
}

/// Shared frame, alignment and glass surface for all four card families.
/// TeamWeekSummaryCards renders the identities selected in TeamWeekCardSelection.swift.
/// Action, Aggressive and Reaction reuse TeamWeekMessageCard for text and supply their details;
/// Streak supplies its layout directly. Card contents do not scroll; the container owns paging.
struct TeamWeekCard<Content: View>: View {
    let dark: Bool
    var tint: Color?
    var watermark: TeamWeekCardWatermark = .none
    var information = false
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            // Scale one banner content layout uniformly, including typography, on smaller phones.
            let reference = TeamWeekCardLayout.referenceSize
            content
                .frame(width: reference.width - 36, height: reference.height - 36, alignment: .top)
                .multilineTextAlignment(.center)
                .padding(18)
                .scaleEffect(geometry.size.width / reference.width, anchor: .topLeading)
        }
        .aspectRatio(TeamWeekCardLayout.aspectRatio, contentMode: .fit)
        .background { watermarkView }
        .modifier(AppGlass(dark: dark, tint: tint, information: information))
    }

    private var watermarkView: some View {
        GeometryReader { geometry in
            Group {
                switch watermark {
                case .none: EmptyView()
                case .flash(let opacity):
                    FlashShape().fill(.primary)
                        .frame(
                            width: geometry.size.height * 1.2, height: geometry.size.height * 1.2
                        )
                        .position(x: geometry.size.width * 0.77, y: geometry.size.height * 0.72)
                        .opacity(opacity)
                case .letter(let text, let opacity):
                    Text(text).font(TeamWeekStyle.font(geometry.size.height * 1.5, heavy: true))
                        .rotationEffect(.degrees(-8))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .opacity(opacity)
                }
            }
            .foregroundStyle(dark ? AppColor.Palette.cream : AppColor.Palette.ink)
        }
        .allowsHitTesting(false)
    }
}

/// Copy supplied by Action, Aggressive and Reaction to the shared TeamWeekMessageCard layout.
struct TeamWeekCardCopy {
    let kicker: String
    let title: String
    let body: String

    init(_ kicker: String, _ title: String, _ body: String) {
        self.kicker = kicker
        self.title = title
        self.body = body
    }
}

/// Action, aggressive and reaction cards differ in copy, tint and the details slot.
/// Composes their shared text layout inside TeamWeekCard.
/// Callers supply progress details, a ranking or an action button.
struct TeamWeekMessageCard<Details: View>: View {
    let copy: TeamWeekCardCopy
    let dark: Bool
    var tint: Color?
    var watermark: TeamWeekCardWatermark = .flash()
    var titleSize: CGFloat = 32
    @ViewBuilder let details: Details

    var body: some View {
        TeamWeekCard(dark: dark, tint: tint, watermark: watermark, information: true) {
            VStack(alignment: .center, spacing: 0) {
                Text(copy.kicker.uppercased()).modifier(TeamWeekHeavyText(12)).tracking(1)
                Spacer(minLength: 6)
                Text(copy.title).modifier(TeamWeekHeavyText(titleSize))
                    .tracking(-0.6).lineSpacing(-3).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Text(copy.body).font(.custom("Nunito-ExtraBold", size: 16, relativeTo: .body))
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                details
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Team-goal details shared by Aggressive and Reaction message cards.
/// The calling card chooses the label explicitly; selection rules are not consulted here.
struct TeamWeekTeamProgress: View {
    let week: TeamWeekPresentation
    let dark: Bool
    var showsRemaining = false

    var body: some View {
        VStack(spacing: 9) {
            HStack(alignment: .lastTextBaseline) {
                Text("Euer Wochenziel").font(TeamWeekStyle.font(16, heavy: true))
                Spacer()
                if showsRemaining {
                    Text("Noch \(week.remaining)").modifier(TeamWeekHeavyText(30))
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text("\(week.completed)").modifier(TeamWeekHeavyText(30))
                        Text("/\(week.target)").font(TeamWeekStyle.font(16, heavy: true))
                    }
                }
            }
            ProgressView(value: week.progress)
                .progressViewStyle(
                    TeamWeekProgressBarStyle(
                        color: dark ? .white : AppColor.Palette.ink, height: 7))
        }
    }

}

/// Member-flash details shared by new-week and personal-feedback cards.
/// The calling card decides whether the viewer is highlighted; ProgressFlash owns flash rendering.
struct TeamWeekMemberProgress: View {
    let week: TeamWeekPresentation
    let dark: Bool
    var highlightsViewer = false
    var onSelectMember: (String) -> Void = { _ in }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 0)], spacing: 8) {
            ForEach(week.members) { member in
                VStack(spacing: 0) {
                    ProgressFlash(
                        completed: member.completed, target: member.target,
                        color: TeamWeekStyle.color(for: member.id, in: week, dark: dark), dark: dark
                    )
                    .frame(width: 64, height: 64)
                    Button {
                        onSelectMember(member.id)
                    } label: {
                        Text(member.id == week.currentUserID ? "Du" : member.name)
                            .font(TeamWeekStyle.font(13, heavy: true)).lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
                .opacity(highlightsViewer && member.id != week.currentUserID ? 0.55 : 1)
                .frame(maxWidth: .infinity)
            }
        }
    }

}

/// Member-ranking details used by the Aggressive catch-up card inside TeamWeekMessageCard.
struct TeamWeekMemberRanking: View {
    let week: TeamWeekPresentation
    let dark: Bool
    var onSelectMember: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(week.rankedMembers.enumerated()), id: \.element.id) { index, member in
                let own = member.id == week.currentUserID
                HStack(spacing: 8) {
                    Text("\(index + 1)").frame(width: 17)
                    Button {
                        onSelectMember(member.id)
                    } label: {
                        Text(own ? "Du" : member.name).lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    ProgressView(value: min(1, member.progress))
                        .progressViewStyle(
                            TeamWeekProgressBarStyle(
                                color: TeamWeekStyle.color(for: member.id, in: week, dark: dark),
                                height: own ? 11 : 8))
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text("\(member.completed)").font(
                            TeamWeekStyle.font(own ? 24 : 18, heavy: true))
                        Text("/\(member.target)").font(
                            TeamWeekStyle.font(own ? 16 : 13, heavy: true))
                    }
                }
                .font(TeamWeekStyle.font(own ? 18 : 14, heavy: true))
                .opacity(own ? 1 : 0.65)
            }
        }
    }
}

/// Bar renderer shared by TeamWeekTeamProgress and TeamWeekMemberRanking.
struct TeamWeekProgressBarStyle: ProgressViewStyle {
    let color: Color
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.10))
                Capsule().fill(color)
                    .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0))
            }
        }
        .frame(height: height)
    }
}

#if DEBUG
    /// Shared container for the four card-family previews. Each family supplies all of its variants;
    /// this view stacks them and sets the light or full Dark Cut appearance, without changing card selection.
    struct TeamWeekCardsPreview<Content: View>: View {
        let dark: Bool
        @ViewBuilder let content: Content

        var body: some View {
            ScrollView {
                VStack(spacing: 16) { content }.padding(18)
            }
            .frame(width: 390)
            .background(DiagonalDarkCutBackrop(stage: dark ? 4 : 0).ignoresSafeArea())
            .environment(\.colorScheme, dark ? .dark : .light)
        }
    }
#endif

import SwiftUI

/// An information page followed by four reward pages.
struct TeamWeekSummaryCards: View {
    let week: TeamWeekPresentation
    let setGoal: () -> Void
    @State private var page: Int? = 0
    @State private var pageProgress: CGFloat = 0
    @State private var heights: [Int: CGFloat] = [:]

    init(week: TeamWeekPresentation, initialPage: Int = 0, setGoal: @escaping () -> Void) {
        self.week = week
        self.setGoal = setGoal
        let initial = min(4, max(0, initialPage))
        _page = State(initialValue: initial)
        _pageProgress = State(initialValue: CGFloat(initial))
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(0..<5, id: \.self) { index in
                            Group {
                                if index == 0 { information } else { reward(index) }
                            }
                            .frame(width: geometry.size.width)
                            .fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) {
                                $0.size.height
                            } action: {
                                heights[index] = $0
                            }
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $page)
                .onScrollGeometryChange(for: CGFloat.self) { scroll in
                    scroll.contentOffset.x / max(1, scroll.containerSize.width)
                } action: { _, progress in
                    pageProgress = progress
                }
            }
            .frame(height: TeamWeekPagerGeometry.height(heights, progress: pageProgress))
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { index in
                    Button {
                        withAnimation(.smooth) { page = index }
                    } label: {
                        Capsule().fill(
                            (week.darkWeek ? Color.white : AppColor.Palette.ink).opacity(
                                page == index ? 1 : 0.28)
                        )
                        .frame(width: page == index ? 13 : 4, height: 4)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 12)
            .glassEffect(.regular, in: .capsule)
            .environment(\.colorScheme, week.darkWeek ? .dark : .light)
        }
    }

    private var goalIsForNextWeek: Bool {
        !TargetPlanning.canSetTargetWeek(week.weekStart, now: week.now)
    }

    private var darkInfo: Bool { week.darkInfo }
    private var accent: Color? {
        switch week.scenario {
        case .nearlyFinished: AppColor.accent
        case .behind: AppColor.Motivation.lime
        case .catchingUp: AppColor.Motivation.lavender
        default: nil
        }
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy.kicker.uppercased()).modifier(TeamWeekHeavyText(12)).tracking(1.4)
            Text(copy.title).modifier(TeamWeekHeavyText(week.scenario.isBold ? 34 : 28))
                .tracking(-1).lineSpacing(-5).fixedSize(horizontal: false, vertical: true)
            Text(copy.body).font(.custom("Nunito-ExtraBold", size: 15, relativeTo: .body))
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true).padding(.bottom, 12)
            switch week.scenario {
            case .setGoal:
                Button(
                    goalIsForNextWeek ? "Ziel für nächste Woche setzen" : "Wochenziel setzen",
                    action: setGoal
                )
                .font(TeamWeekStyle.font(16, heavy: true))
                .buttonStyle(.glassProminent).tint(AppColor.accent)
            case .newWeek, .personallyOnTrack:
                HStack(spacing: 0) {
                    ForEach(week.members) { member in
                        VStack(spacing: 0) {
                            TeamWeekProgressFlash(
                                completed: member.completed, target: member.target,
                                color: TeamWeekStyle.color(
                                    for: member.id, in: week, dark: darkInfo), dark: darkInfo
                            )
                            .frame(width: 86, height: 86)
                            Text(member.id == week.currentUserID ? "Du" : member.name)
                                .font(TeamWeekStyle.font(12, heavy: true)).lineLimit(1)
                        }
                        .opacity(
                            week.scenario == .personallyOnTrack && member.id != week.currentUserID
                                ? 0.55 : 1
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            case .catchingUp: ranking
            default: teamProgress
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { backgroundMark }
        .modifier(AppGlass(dark: darkInfo, tint: accent, information: true))
        .clipShape(.rect(cornerRadius: 26))
    }

    private var backgroundMark: some View {
        GeometryReader { geometry in
            let letter =
                week.scenario == .catchingUp
                ? "L"
                : [.personallyOnTrack, .teamOnTrack].contains(week.scenario) ? "W" : ""
            Group {
                if letter.isEmpty {
                    FlashShape().fill(.primary)
                        .frame(
                            width: geometry.size.height * 1.2, height: geometry.size.height * 1.2
                        )
                        .position(x: geometry.size.width * 0.77, y: geometry.size.height * 0.72)
                } else {
                    Text(letter).font(TeamWeekStyle.font(geometry.size.height * 1.5, heavy: true))
                        .rotationEffect(.degrees(-8))
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }.opacity(week.scenario.isBold ? 0.075 : 0.045)
        }.allowsHitTesting(false)
    }

    private var teamProgress: some View {
        VStack(spacing: 9) {
            HStack(alignment: .lastTextBaseline) {
                Text("Euer Wochenziel").font(TeamWeekStyle.font(13, heavy: true))
                Spacer()
                if week.scenario == .nearlyFinished {
                    Text("Noch \(week.remaining)").modifier(TeamWeekHeavyText(30))
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text("\(week.completed)").modifier(TeamWeekHeavyText(30))
                        Text("/\(week.target)").font(TeamWeekStyle.font(18, heavy: true))
                    }
                }
            }
            ProgressView(value: week.progress)
                .progressViewStyle(
                    TeamWeekProgressBarStyle(
                        color: darkInfo ? .white : AppColor.Palette.ink,
                        height: 7))
        }
    }

    private var ranking: some View {
        VStack(spacing: 10) {
            ForEach(Array(week.rankedMembers.enumerated()), id: \.element.id) { index, member in
                let own = member.id == week.currentUserID
                HStack(spacing: 10) {
                    Text("\(index + 1)").frame(width: 17)
                    Text(own ? "Du" : member.name).lineLimit(1)
                    ProgressView(value: min(1, member.progress))
                        .progressViewStyle(
                            TeamWeekProgressBarStyle(
                                color: TeamWeekStyle.color(
                                    for: member.id, in: week, dark: darkInfo),
                                height: own ? 11 : 8))
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text("\(member.completed)").font(
                            TeamWeekStyle.font(own ? 30 : 19, heavy: true))
                        Text("/\(member.target)").font(
                            TeamWeekStyle.font(own ? 18 : 12, heavy: true))
                    }
                }
                .font(TeamWeekStyle.font(own ? 21 : 14, heavy: true))
                .opacity(own ? 1 : 0.65)
            }
        }
    }

    private struct Copy {
        let kicker: String
        let title: String
        let body: String
        init(_ kicker: String, _ title: String, _ body: String) {
            self.kicker = kicker
            self.title = title
            self.body = body
        }
    }
    private var copy: Copy {
        if week.isPast {
            return Copy(
                "Woche im Rückblick",
                week.remaining == 0 && week.target > 0
                    ? "Gemeinsam durchgezogen." : "Jeder Ident zählt.",
                "\(week.completed) von \(week.target) Idents. Neue Woche, neue Chance."
            )
        }
        switch week.scenario {
        case .setGoal:
            return Copy(
                "Nicht planlos durchs Leben", "Her mit deinem Ziel!",
                goalIsForNextWeek
                    ? "Die Planung für diese Woche ist geschlossen. Leg jetzt dein Ziel für nächste Woche fest."
                    : "Setz dir ein Wochenziel und mach den ersten Schritt. Dein Team wartet auf dich."
            )
        case .nearlyFinished:
            return Copy(
                "So nah dran", "1 Noch. Fritten in die Tüte jetzt!",
                "\(week.completed) von \(week.target) Male habt ihr schon durchgezogen. "
                    + "Peinlich, wenn das jetzt so kurz vorm Ziel eine Antiklimax wird."
            )
        case .behind:
            return Copy(
                "Peinlichrrrr \(week.currentMember?.name ?? "Team")", "Starte jetzt ein Comeback!",
                "Deswegen wurdest du bei deinem letzten Job-Interview abgelehnt. "
                    + "Zieh jetzt endlich mal durch. Von nichts kommt nichts..."
            )
        case .catchingUp:
            return Copy(
                "Opfer? L", "Dein Team zieht durch (du nicht).",
                "Die anderen sind schon fast fertig. Dir fehlen noch \(week.currentMember?.remaining ?? 0) Idents. "
                    + "Dein nächster zählt."
            )
        case .newWeek:
            return Copy(
                "Neue Woche. Abfahrt.", "Fetzt du den 1. Ident diese Woche?",
                "Setzt du dir nur Ziele, oder bist du ein Macher?"
            )
        case .personallyOnTrack:
            return Copy(
                "Macher", "Du bist auf Kurs!",
                "Geil, dass du durchziehst, ehrlich! Du darfst einmal dabben, ohne dabei Aura zu verlieren."
            )
        case .teamOnTrack:
            return Copy(
                "Macher Team <3", "Dein Team ist auf Kurs.",
                week.remaining == 0
                    ? "Wochenziel erreicht. Zusammen. Weiter."
                    : "Ihr zieht gemeinsam durch. Eure nächsten Termine stehen."
            )
        }
    }

}

extension TeamWeekSummaryCards {
    private func reward(_ style: Int) -> some View {
        VStack(alignment: style == 1 ? .center : .leading, spacing: 15) {
            switch style {
            case 1:
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
            case 2:
                HStack {
                    VStack(alignment: .leading) {
                        Text("STREAK LEVEL").font(TeamWeekStyle.font(11, heavy: true)).tracking(1.3)
                        Text(String(format: "%02d", week.streak)).font(
                            TeamWeekStyle.font(62, heavy: true))
                    }
                    Spacer()
                    TeamWeekStreakIcon(streak: week.streak)
                }
                Text("Ihr seid on fire.").font(TeamWeekStyle.font(29, heavy: true))
                ProgressView(value: Double(week.streak), total: Double(nextMilestone)).tint(
                    AppColor.Streak.glow)
                Text("\(week.streak) / \(nextMilestone) Wochen bis zum Meilenstein")
            case 3:
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
                                    AppColor.Streak.glow.opacity(index < week.streak ? 0.85 : 0.16),
                                    in: .circle)
                            Text("Woche \(index + 1)").font(TeamWeekStyle.font(9))
                        }
                    }
                }
            default:
                ZStack {
                    Image(systemName: "medal.fill").font(.system(size: 110)).foregroundStyle(
                        AppColor.Streak.glow.opacity(0.35))
                    TeamWeekStreakIcon(streak: week.streak)
                }.frame(maxWidth: .infinity).padding(.vertical, 10)
                Text(week.streak == 0 ? "DEIN ERSTER MEILENSTEIN WARTET" : "MEILENSTEIN ERREICHT")
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
        .padding(26)
        .frame(maxWidth: .infinity, alignment: style == 1 ? .center : .leading)
        .modifier(AppGlass(dark: week.darkStreak))
    }

    private var nextMilestone: Int { (week.streak / 5 + 1) * 5 }
}

/// Capsule progress bars with an explicit height.
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

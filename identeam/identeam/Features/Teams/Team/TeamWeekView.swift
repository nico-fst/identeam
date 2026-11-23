import SwiftData
import SwiftUI

struct TeamWeekView: View {
    let slug: String
    @State private var hasLoadedFreshTeamWeek = false
    @State private var isLoadingWeek = false
    @State private var showTeamSettings = false
    @State private var showTeamInfo = false
    @State private var showAuraInfo = false
    @State private var showDatePicker = false
    @State private var selectedProfileUser: User?
    @AppStorage("userID") private var userID: String = ""
    @EnvironmentObject var vm: AppVM
    @EnvironmentObject var teamsVM: TeamsVM
    @Environment(\.modelContext) private var ctx
    @Environment(\.identDetailPresentation) private var identPresentation

    @StateObject var teamVM: TeamWeekVM

    init(
        slug: String, teamVM: TeamWeekVM = TeamWeekVM(),
        preview: TeamWeekPreviewConfiguration? = nil, referenceDate: Date = .now
    ) {
        self.preview = preview
        self.referenceDate = referenceDate
        self.slug = slug
        _teamVM = StateObject(wrappedValue: teamVM)
    }

    private let referenceDate: Date
    private let preview: TeamWeekPreviewConfiguration?
    private var viewerID: String { preview?.userID ?? userID }
    @Namespace private var transitions

    let isXcodePreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    @Query private var teams: [Team]
    private var team: Team? {
        teams.first(where: { $0.slug == slug })
    }

    @Query private var teamWeeks: [TeamWeek]
    private var teamWeek: TeamWeek? {
        teamWeeks.first {
            $0.slug == slug
                && AppCalendar.startOfWeek(containing: $0.weekStart)
                    == AppCalendar.startOfWeek(containing: teamVM.weekStart)
        }
    }

    private var darkCutStage: Int {
        teamWeek.map {
            TeamWeekPresentation(week: $0, currentUserID: viewerID, now: referenceDate).darkCutStage
        } ?? 0
    }

    private var lastWeeks: [TeamWeek] {
        Array(
            teamWeeks
                .filter {
                    $0.slug == slug && $0.weekStart <= teamVM.weekStart
                }
                .sorted { $0.weekStart > $1.weekStart }
                .prefix(4)
        )
    }

    private var month: Date {
        AppCalendar.startOfMonth(containing: teamVM.referenceDate)
    }

    var body: some View {
        Group {  // .refreshable doesn't work on plain View
            if let team {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let teamWeek {
                            let presentation = TeamWeekPresentation(
                                week: teamWeek, currentUserID: viewerID, now: referenceDate)
                            header(team: team, week: presentation)
                            TeamWeekSummaryCards(
                                week: presentation, stacked: preview != nil,
                                onSelectMember: showProfile
                            ) {
                                teamVM.showSettingTarget = true
                            }
                            .id(teamVM.weekStart)
                        } else {
                            Text(team.name).font(TeamWeekStyle.font(32, heavy: true))
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(selectedWeek.title)
                                    .font(TeamWeekStyle.font(19, heavy: true))
                                Spacer(minLength: 4)
                                weekNavigation
                            }
                            .foregroundStyle(
                                darkCutStage >= 3
                                    ? AppColor.Palette.cream : AppColor.Palette.ink)
                            overviewContent
                        }
                        if !selectedWeek.isFuture, !lastWeeks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Letzte Wochen").font(TeamWeekStyle.font(19, heavy: true))
                                    .foregroundStyle(
                                        darkCutStage >= 4
                                            ? AppColor.Palette.cream : AppColor.Palette.ink)
                                LastWeeksCompletionView(
                                    lastWeeks: lastWeeks, referenceDate: referenceDate,
                                    animated: true
                                )
                                .frame(maxWidth: .infinity)
                                .padding(18)
                                .modifier(AppGlass(dark: darkCutStage >= 4))
                            }
                        }
                        TeamWeekActionsSection(
                            slug: team.slug, hasLoadedFreshTeamWeek: hasLoadedFreshTeamWeek,
                            dark: darkCutStage >= 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .modifier(TeamWeekScrollingBackdrop(stage: darkCutStage))
                .refreshable { await reloadWeek() }
                .toolbar { teamToolbar(for: team) }
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarColorScheme(
                    darkCutStage >= 2 ? .dark : .light, for: .navigationBar
                )
                .toolbarColorScheme(darkCutStage >= 3 ? .dark : .light, for: .tabBar)
                .toolbarBackground(
                    darkCutStage >= 3 ? AppColor.Palette.ink : AppColor.Palette.cream, for: .tabBar
                )
                .toolbarBackground(.visible, for: .tabBar)
                .sheet(isPresented: $teamVM.showSettingTarget) {
                    NavigationStack {
                        TargetPicker(
                            slug: team.slug,
                            referenceDate: max(
                                teamVM.weekStart, TargetPlanning.firstPlannableWeek())
                        ) { didChange in
                            teamVM.showSettingTarget = false
                            if didChange {
                                Task {
                                    await reloadWeek()
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showTeamSettings) {
                    NavigationStack {
                        TeamSettingsView(
                            slug: team.slug,
                            teamName: team.name,
                            userID: viewerID
                        )
                    }
                    .navigationTransition(
                        .zoom(sourceID: "settings-button", in: transitions)
                    )
                }
                .sheet(isPresented: $showTeamInfo) {
                    TeamInfoView(team: team)
                        .navigationTransition(
                            .zoom(sourceID: "info-button", in: transitions)
                        )
                }
            } else {
                Color.clear
            }
        }
        .task(
            id:
                "\(slug)|\(AppCalendar.dateString(teamVM.weekStart))"
        ) {
            hasLoadedFreshTeamWeek = preview != nil || isXcodePreview
            if !hasLoadedFreshTeamWeek, team != nil { await reloadWeek() }
        }
        .environmentObject(teamVM)
        .sheet(item: $selectedProfileUser) { user in
            NavigationStack {
                TeamMemberProfileView(
                    user: user, slug: slug, month: month, viewerID: viewerID,
                    referenceDate: referenceDate, showsMonth: !selectedWeek.isFuture)
            }
        }
    }

    @MainActor
    private func reloadWeek() async {
        guard preview == nil, !isXcodePreview else { return }
        let selectedWeek = teamVM.weekStart
        isLoadingWeek = true
        defer {
            if teamVM.weekStart == selectedWeek {
                isLoadingWeek = false
            }
        }

        guard
            await teamsVM.reloadTeamWeek(slug: slug, weekStart: selectedWeek, vm: vm, ctx: ctx)
                != nil,
            !Task.isCancelled, teamVM.weekStart == selectedWeek
        else { return }
        hasLoadedFreshTeamWeek = true

        guard selectedWeek <= AppCalendar.startOfWeek(containing: referenceDate) else { return }
        // History needs only the three preceding weeks; the profile owns month loading.
        for offset in 1...3 {
            let weekStart = AppCalendar.calendar.date(
                byAdding: .weekOfYear, value: -offset, to: selectedWeek)!
            guard !Task.isCancelled, teamVM.weekStart == selectedWeek else {
                return
            }
            guard
                await teamsVM.reloadTeamWeek(slug: slug, weekStart: weekStart, vm: vm, ctx: ctx)
                    != nil
            else {
                return
            }
        }
    }
}

extension TeamWeekView {
    private func header(team: Team, week: TeamWeekPresentation) -> some View {
        HStack(alignment: .center) {
            Button {
                showAuraInfo = true
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(team.name.uppercased())
                        .font(TeamWeekStyle.font(11, heavy: true)).tracking(1.5)
                        .foregroundStyle(Color.accentColor)
                    Text("\(week.completed)/\(week.target) Idents").modifier(TeamWeekHeavyText(31))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(week.darkHeader ? AppColor.Palette.cream : AppColor.Palette.ink)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showAuraInfo, attachmentAnchor: .rect(.bounds), arrowEdge: .top)
            {
                TeamWeekAuraLegend().padding(20).presentationCompactAdaptation(.popover)
            }
            Spacer(minLength: 10)
            TeamWeekStreakInfoButton(streak: week.streak)
        }
        .padding(.bottom, 22)
    }

    fileprivate var weekNavigation: some View {
        HStack(spacing: 6) {
            Button {
                teamVM.changeWeek(by: -7)
            } label: {
                Image(systemName: "chevron.left").frame(width: 22, height: 30)
            }
            Button {
                showDatePicker = true
            } label: {
                Text(weekRange).font(TeamWeekStyle.font(11, heavy: true)).lineLimit(1)
            }
            .popover(isPresented: $showDatePicker) {
                VStack(spacing: 12) {
                    TeamWeekCalendar(selection: $teamVM.referenceDate) { showDatePicker = false }
                    Button("Diese Woche") {
                        teamVM.referenceDate = .now
                        showDatePicker = false
                    }
                    .buttonStyle(.glassProminent)
                    .tint(AppColor.accent)
                }.padding().frame(idealWidth: 340).presentationCompactAdaptation(.popover)
            }

            Button {
                teamVM.changeWeek(by: 7)
            } label: {
                Image(systemName: "chevron.right").frame(width: 22, height: 30)
            }
        }
        .font(.system(size: 11, weight: .bold))
        .padding(.horizontal, 5)
        .modifier(AppGlass(dark: darkCutStage >= 3))
    }

    private var selectedWeek: TeamWeekPresentation {
        TeamWeekPresentation(
            weekStart: teamVM.weekStart, members: [], currentUserID: viewerID,
            streak: 0, now: referenceDate
        )
    }

    private var weekRange: String { TeamWeekPresentation.dateRange(for: teamVM.weekStart) }

    @ViewBuilder
    fileprivate var overviewContent: some View {
        if let teamWeek {
            TeamWeekGrid(
                slug: slug,
                week: TeamWeekPresentation(
                    week: teamWeek, currentUserID: viewerID, now: referenceDate),
                members: preview == nil ? teamWeek.members : [],
                initiallyDetailed: false, onSelectMember: showProfile
            ) { identID, source in
                guard
                    let member = teamWeek.members.first(where: { member in
                        member.idents.contains { TeamWeekPresentation.identID($0) == identID }
                    }),
                    let ident = member.idents.first(where: {
                        TeamWeekPresentation.identID($0) == identID
                    })
                else { return }
                identPresentation?.present(
                    ident: ident, author: member.user, slug: slug,
                    source: source, teamVM: teamVM)
            }
            .id(teamVM.weekStart)
        } else if isLoadingWeek {
            ProgressView().frame(maxWidth: .infinity).padding(40)
        } else {
            ContentUnavailableView {
                Label("Woche nicht geladen", systemImage: "wifi.exclamationmark")
            } actions: {
                Button("Erneut laden") { Task { await reloadWeek() } }
            }
        }
    }

    private func showProfile(_ memberID: String) {
        selectedProfileUser = teamWeek?.members.first { $0.user.userID == memberID }?.user
    }

    @ToolbarContentBuilder
    fileprivate func teamToolbar(for team: Team) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showTeamSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .matchedTransitionSource(id: "settings-button", in: transitions)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showTeamInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
            .matchedTransitionSource(id: "info-button", in: transitions)
        }
    }
}

#if DEBUG
    #Preview("Dark Cut · 0") { TeamWeekScreenPreview(stage: 0) }
    #Preview("Dark Cut · 1") { TeamWeekScreenPreview(stage: 1) }
    #Preview("Dark Cut · 2") { TeamWeekScreenPreview(stage: 2) }
    #Preview("Dark Cut · 3") { TeamWeekScreenPreview(stage: 3) }
    #Preview("Dark Cut · 4") { TeamWeekScreenPreview(stage: 4) }
#endif

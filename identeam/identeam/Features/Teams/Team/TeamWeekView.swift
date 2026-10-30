import SwiftData
import SwiftUI

struct TeamWeekView: View {
    let slug: String
    @State private var hasLoadedFreshTeamWeek = false
    @State private var isLoadingMonth = false
    @State private var showTeamSettings = false
    @State private var showTeamInfo = false
    @State private var showAuraInfo = false
    @State private var showDatePicker = false
    @AppStorage("userID") private var userID: String = ""
    @EnvironmentObject var vm: AppVM
    @EnvironmentObject var teamsVM: TeamsVM
    @Environment(\.modelContext) private var ctx

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
                    == AppCalendar.startOfWeek(contasning: teamVM.weekStart)
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

    private var monthWeeks: [TeamWeek] {
        let weekStarts = AppCalendar.weekStartsInMonth(containing: month)
        return teamWeeks.filter { $0.slug == slug && weekStarts.contains($0.weekStart) }
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
                                week: presentation, initialPage: preview?.card ?? 0
                            ) {
                                teamVM.showSettingTarget = true
                            }
                            .id(teamVM.weekStart)
                        } else {
                            Text(team.name).font(TeamWeekStyle.font(32, heavy: true))
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(selectedWeekTitle)
                                    .font(TeamWeekStyle.font(19, heavy: true))
                                Spacer(minLength: 4)
                                weekNavigation
                            }
                            .foregroundStyle(
                                darkCutStage >= 3
                                    ? AppColor.Palette.cream : AppColor.Palette.ink)
                            overviewContent
                        }
                        if !lastWeeks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Letzte Wochen").font(TeamWeekStyle.font(19, heavy: true))
                                    .foregroundStyle(
                                        darkCutStage >= 4
                                            ? AppColor.Palette.cream : AppColor.Palette.ink)
                                LastWeeksCompletionView(lastWeeks: lastWeeks, animated: true)
                                    .padding(18)
                                    .modifier(AppGlass(dark: darkCutStage >= 4))
                            }
                        }
                        monthContent
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
                .sheet(
                    item: $teamVM.selectedIdent,
                    onDismiss: {
                        teamVM.commentInput = ""
                        teamVM.commentError = ""
                    }
                ) { ident in
                    NavigationStack {
                        if let member = teamWeek?.members.first(where: { member in
                            member.idents.contains(where: { $0.id == ident.id })
                        }) {
                            IdentDetailView(ident: ident, member: member, slug: team.slug)
                        } else {
                            ContentUnavailableView(
                                "Failed to load Ident",
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                    }
                    .presentationDetents([.large])
                }
            } else {
                Color.clear
            }
        }
        .task(
            id:
                "\(slug)|\(AppCalendar.dateString(teamVM.weekStart))|\(AppCalendar.dateString(month))"
        ) {
            hasLoadedFreshTeamWeek = preview != nil || isXcodePreview
            if !hasLoadedFreshTeamWeek, team != nil { await reloadWeek() }
        }
        .environmentObject(teamVM)
    }

    @MainActor
    private func reloadWeek() async {
        guard preview == nil, !isXcodePreview else { return }
        let selectedWeek = teamVM.weekStart
        let selectedMonth = month
        isLoadingMonth = true
        defer {
            if teamVM.weekStart == selectedWeek && month == selectedMonth {
                isLoadingMonth = false
            }
        }

        guard
            await teamsVM.reloadTeamWeek(slug: slug, weekStart: selectedWeek, vm: vm, ctx: ctx)
                != nil,
            !Task.isCancelled, teamVM.weekStart == selectedWeek, month == selectedMonth
        else { return }
        hasLoadedFreshTeamWeek = true

        for weekStart in AppCalendar.weekStartsInMonth(containing: selectedMonth)
        where weekStart != selectedWeek {
            guard !Task.isCancelled, teamVM.weekStart == selectedWeek, month == selectedMonth else {
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
        .glassEffect(.regular, in: .capsule)
        .environment(\.colorScheme, darkCutStage >= 3 ? .dark : .light)
    }

    private var selectedWeekTitle: String {
        TeamWeekPresentation(
            weekStart: teamVM.weekStart, members: [], currentUserID: viewerID,
            streak: 0, now: referenceDate
        ).title
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
                initiallyDetailed: preview?.detailed ?? false
            ) { identID in
                teamVM.selectedIdent = teamWeek.members.flatMap(\.idents).first {
                    TeamWeekPresentation.identID($0) == identID
                }
            }
            .id(teamVM.weekStart)
        } else if isLoadingMonth {
            ProgressView().frame(maxWidth: .infinity).padding(40)
        } else {
            ContentUnavailableView {
                Label("Woche nicht geladen", systemImage: "wifi.exclamationmark")
            } actions: {
                Button("Erneut laden") { Task { await reloadWeek() } }
            }
        }
    }

    private var monthContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dein Monat").font(TeamWeekStyle.font(19, heavy: true))
                .foregroundStyle(
                    darkCutStage >= 4 ? AppColor.Palette.cream : AppColor.Palette.ink)
            if monthWeeks.count == AppCalendar.weekStartsInMonth(containing: month).count {
                LastMonthView(
                    month: month,
                    personalWeeks: monthWeeks.compactMap {
                        PersonalWeek(teamWeek: $0, userID: viewerID)
                    }
                )
                .padding(16)
                .modifier(AppGlass(dark: darkCutStage >= 4))
            } else if isLoadingMonth {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else {
                Text("Monat nicht geladen. Zum Aktualisieren nach unten ziehen.")
                    .foregroundStyle(AppColor.muted)
            }
        }
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

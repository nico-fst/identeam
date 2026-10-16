import SwiftData
import SwiftUI

struct TeamWeekView: View {
    let slug: String

    enum Tab: Hashable {
        case team
        case personal
    }
    @State private var selectedTab: Tab = .team

    @State private var hasLoadedFreshTeamWeek = false
    @State private var isLoadingMonth = false
    @State private var showTeamSettings = false
    @State private var showTeamInfo = false

    @AppStorage("userID") private var userID: String = ""

    @EnvironmentObject var vm: AppVM
    @EnvironmentObject var teamsVM: TeamsVM
    @Environment(\.modelContext) private var ctx

    @StateObject var teamVM: TeamWeekVM

    // allows injecting for Preview
    init(slug: String, teamVM: TeamWeekVM = TeamWeekVM()) {
        self.slug = slug
        _teamVM = StateObject(wrappedValue: teamVM)
    }

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
                List {
                    Group {
                        weekNavigation
                            .listRowSeparator(.hidden)

                        IgniteSegmentedPicker(
                            "View", selection: $selectedTab, options: [.team, .personal]
                        ) {
                            $0 == .team ? "Team" : "Personal"
                        }
                        .listRowSeparator(.hidden)

                        TeamWeekActionsSection(
                            slug: team.slug, hasLoadedFreshTeamWeek: hasLoadedFreshTeamWeek)

                        overviewContent

                        Section {
                            Text("Coming soon :)")
                                .foregroundStyle(IgniteColor.text.opacity(0.3))
                        } header: {
                            Text("Chat")
                                .font(.nunito(.headline))
                        }
                    }
                    .listRowBackground(IgniteColor.surface)
                }
                .igniteListColors()
                .refreshable {
                    await reloadWeek()
                }
                .listStyle(InsetGroupedListStyle())
                .toolbar { teamToolbar(for: team) }
                .sheet(isPresented: $teamVM.showSettingTarget) {
                    NavigationStack {
                        TargetPicker(
                            slug: team.slug
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
                            userID: userID
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
            hasLoadedFreshTeamWeek = false
            if !isXcodePreview {
                if team != nil {
                    await reloadWeek()
                }
            } else {
                hasLoadedFreshTeamWeek = true
            }
        }
        .environmentObject(teamVM)
    }

    @MainActor
    private func reloadWeek() async {
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
    fileprivate var weekNavigation: some View {
        HStack {
            Button {
                teamVM.changeWeek(by: -7)
            } label: {
                Image(systemName: "chevron.left")
                    .padding(5)
            }
            .buttonStyle(.glassProminent)
            .tint(.accent)
            .foregroundStyle(IgniteColor.onAccent)

            Spacer()

            Button {
                teamVM.referenceDate = Date()
            } label: {
                Text(TargetPlanning.weekName(for: teamVM.referenceDate))
                    .font(.nunito(.title3))
                    .padding(5)
            }
            .buttonStyle(.glass(.regular.tint(IgniteColor.selection)))

            Spacer()

            Button {
                teamVM.changeWeek(by: 7)
            } label: {
                Image(systemName: "chevron.right")
                    .padding(5)
            }
            .buttonStyle(.glassProminent)
            .tint(.accent)
            .foregroundStyle(IgniteColor.onAccent)
        }
        .disabled(!hasLoadedFreshTeamWeek)
    }

    @ViewBuilder
    fileprivate var overviewContent: some View {
        if hasLoadedFreshTeamWeek, let teamWeek {
            switch selectedTab {
            case .team:
                CurrentWeekWidget(teamWeek: teamWeek) { ident in
                    teamVM.selectedIdent = ident
                }
                CurrentProgressWidget(week: teamWeek)
                Section {
                    LastWeeksCompletionView(lastWeeks: lastWeeks, animated: true)
                } header: {
                    Text("Completion of last weeks")
                        .font(.nunito(.headline))
                }
            case .personal:
                if monthWeeks.count
                    == AppCalendar.weekStartsInMonth(containing: month).count
                {
                    Section {
                        LastMonthView(
                            month: month,
                            personalWeeks: monthWeeks.compactMap {
                                PersonalWeek(teamWeek: $0, userID: userID)
                            }
                        )
                    } header: {
                        Text("Month Overview")
                            .font(.nunito(.headline))
                    }
                } else {
                    Section {
                        if isLoadingMonth {
                            ProgressView()
                        } else {
                            Text("Month could not be loaded. Pull to refresh.")
                                .foregroundStyle(IgniteColor.muted)
                        }
                    }
                }
            }

        } else {
            Section {
                ProgressView()
            }
        }
    }

    @ToolbarContentBuilder
    fileprivate func teamToolbar(for team: Team) -> some ToolbarContent {
        // Team name etc.
        ToolbarItem(placement: .topBarLeading) {
            VStack {
                Text(team.name)
                    .font(.nunito(.headline))
                    .fixedSize(horizontal: true, vertical: false)  // so text doesn't get cropped
                TeamStreakLabel(week: teamWeek)
                    .labelStyle(CompactStreakLabelStyle())
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.nunito(.footnote))
                    .foregroundStyle(IgniteColor.streak)
            }
        }
        .sharedBackgroundVisibility(.hidden)  // so text is not surrounded by glass

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

private struct TeamViewPreviewContainer: View {
    let container: ModelContainer
    @StateObject private var teamVM: TeamWeekVM

    init(openIdent: Bool = false) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        let container = try! ModelContainer(
            for: Team.self,
            TeamWeek.self,
            TeamMember.self,
            User.self,
            Ident.self,
            S3Item.self,
            Comment.self,
            configurations: config
        )

        let team = Team.templateKanten
        let teamWeek = TeamWeek.templateKanten

        container.mainContext.insert(team)
        container.mainContext.insert(teamWeek)
        container.mainContext.insert(TeamWeek.templateStreakKanten)
        container.mainContext.insert(TeamWeek.templateBadKanten)
        container.mainContext.insert(TeamWeek.templateGoodkanten)
        container.mainContext.insert(TeamWeek.templateFrozenKanten)

        let teamVM = TeamWeekVM()

        if openIdent {
            teamVM.selectedIdent =
                teamWeek.members
                .flatMap(\.idents)
                .first
        }

        self.container = container
        _teamVM = StateObject(wrappedValue: teamVM)
    }

    var body: some View {
        TeamWeekView(
            slug: "die-kanten",
            teamVM: teamVM
        )
        .environmentObject(AppVM())
        .environmentObject(TeamsVM())
        .modelContainer(container)
    }
}

#Preview("Default") {
    TeamViewPreviewContainer()
}

#Preview("Ident Open") {
    TeamViewPreviewContainer(openIdent: true)
}

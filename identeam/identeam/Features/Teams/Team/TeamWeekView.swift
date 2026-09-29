import SwiftData
import SwiftUI

struct TeamWeekView: View {
    let slug: String

    @State private var hasLoadedFreshTeamWeek = false
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

    var body: some View {
        Group {  // .refreshable doesn't work on plain View
            if let team {
                List {
                    // << This week >>
                    HStack {
                        Button {
                            teamVM.changeWeek(by: -7)
                        } label: {
                            Image(systemName: "chevron.left")
                                .padding(5)
                        }
                        .buttonStyle(.glassProminent)

                        Spacer()

                        Button {
                            teamVM.referenceDate = Date()
                        } label: {
                            Text(TargetPlanning.weekName(for: teamVM.referenceDate))
                                .font(.title3)
                                .padding(5)
                        }
                        .buttonStyle(.glass)

                        Spacer()

                        Button {
                            teamVM.changeWeek(by: 7)
                        } label: {
                            Image(systemName: "chevron.right")
                                .padding(5)
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .disabled(!hasLoadedFreshTeamWeek)

                    if hasLoadedFreshTeamWeek, let teamWeek {
                        CurrentWeekWidget(teamWeek: teamWeek) { ident in
                            teamVM.selectedIdent = ident
                        }
                        CurrentProgressWidget(week: teamWeek)
                        LastWeeksCompletionWidget(lastWeeks: lastWeeks)
                    } else {
                        Section {
                            ProgressView()
                        }
                    }

                    TeamWeekActionsSection(
                        slug: team.slug, hasLoadedFreshTeamWeek: hasLoadedFreshTeamWeek)

                    Section("Chat") {
                        Text("Coming soon :)")
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .refreshable {
                    await reloadWeek()
                }
                .listStyle(InsetGroupedListStyle())
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Text(team.name)
                            .font(.headline)
                            .fixedSize(horizontal: true, vertical: false)  // so text doesn't get cropped
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
        .task(id: "\(slug)|\(AppCalendar.dateString(teamVM.weekStart))") {
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
        if await teamsVM.reloadTeamWeek(slug: slug, weekStart: teamVM.weekStart, vm: vm, ctx: ctx)
            != nil
        {
            if !Task.isCancelled { hasLoadedFreshTeamWeek = true }
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

import SwiftData
import SwiftUI

struct TeamWeekView: View {
    let slug: String

    @State private var hasLoadedFreshTeamWeek = false
    @State private var showTeamSettings = false
    @State private var showTeamInfo = false

    @AppStorage("userID") private var userID: String = ""

    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var teamsVM: TeamsViewModel
    @StateObject var teamVM = TeamWeekViewModel()
    @Environment(\.modelContext) private var ctx

    @Namespace private var transitions

    let isXcodePreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    @Query private var teams: [Team]
    private var team: Team? {
        teams.first(where: { $0.slug == slug })
    }

    @Query private var teamWeeks: [TeamWeek]
    private var teamWeek: TeamWeek? {
        teamWeeks.first {
            $0.slug == slug && $0.weekStart == teamVM.weekStart
        }
    }

    var body: some View {
        Group { // .refreshable doesn't work on plain View
            if let team {
                    // << This week >>
                    HStack {
                        Button {
                            teamVM.changeWeek(by: -7)
                        } label: {
                            Image(systemName: "chevron.left")
                                .padding(5)
                        }

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
                    }
                    .padding()
                    .disabled(!hasLoadedFreshTeamWeek)
                    .buttonStyle(.glassProminent)
                
                List {
                    if hasLoadedFreshTeamWeek, let teamWeek {
                        CurrentWeekWidget(teamWeek: teamWeek) { ident in
                            teamVM.selectedIdent = ident
                        }
                        
                        CurrentProgressWidget(week: teamWeek)
                    } else {
                        Section("TeamWeek") {
                            ProgressView()
                        }
                    }

                    TeamWeekActionsSection(slug: team.slug, hasLoadedFreshTeamWeek: hasLoadedFreshTeamWeek)

                    Section("Chat") {
                        Text("Coming soon :)")
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                    .navigationTitle(team.name)
                }
                .refreshable {
                    await reloadWeek()
                }
                .listStyle(InsetGroupedListStyle())
                .toolbar {
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
                ContentUnavailableView(
                    "Team not found",
                    systemImage: "person.2.slash"
                )
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
        if await teamsVM.reloadTeamWeek(slug: slug, weekStart: teamVM.weekStart, vm: vm, ctx: ctx) != nil {
            if !Task.isCancelled { hasLoadedFreshTeamWeek = true }
        }
    }
}

private struct TeamView_PreviewContainer: View {
    let container: ModelContainer
    @StateObject private var teamVM: TeamWeekViewModel

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

        let teamVM = TeamWeekViewModel()

        if openIdent {
            teamVM.selectedIdent = teamWeek.members
                .flatMap(\.idents)
                .first
        }

        self.container = container
        _teamVM = StateObject(wrappedValue: teamVM)
    }

    var body: some View {
        TeamWeekView(slug: "die-kanten")
            .environmentObject(AppViewModel())
            .environmentObject(TeamsViewModel())
            .environmentObject(teamVM)
            .modelContainer(container)
    }
}

#Preview("Default") {
    TeamView_PreviewContainer()
}

#Preview("Ident Open") {
    TeamView_PreviewContainer(openIdent: true)
}

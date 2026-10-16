import SwiftData
import SwiftUI

struct TeamsView: View {
    @EnvironmentObject var teamsVM: TeamsVM
    @EnvironmentObject var vm: AppVM
    @EnvironmentObject var authVM: AuthVM
    @EnvironmentObject var navVM: NavigationVM
    @Environment(\.modelContext) private var modelContext

    @Query private var teams: [Team]

    var body: some View {
        NavigationStack(path: $navVM.teamPath) {
            List {
                Group {
                    ForEach(teams) { team in
                        NavigationLink(value: Route.team(slug: team.slug)) {
                            Text(team.name)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await teamsVM.tryLeavingTeam(
                                        ctx: modelContext,
                                        vm: vm,
                                        slug: team.slug
                                    )
                                }
                            } label: {
                                Text("Leave")
                            }
                        }
                    }

                    Button("Join existing Team") {
                        teamsVM.showingJoinSheet.toggle()
                    }
                }
                .listRowBackground(IgniteColor.surface)
            }
            .igniteListColors()
            .refreshable {
                await teamsVM.reloadTeams(ctx: modelContext)
            }
            .task {
                await teamsVM.reloadTeams(ctx: modelContext)
            }
            .navigationTitle("Teams")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .team(let slug):
                    TeamWeekView(slug: slug)
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        teamsVM.showingCreateSheet.toggle()
                    } label: {
                        Label("Create", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $teamsVM.showingJoinSheet) {
                joinTeamSheet
            }
            .sheet(isPresented: $teamsVM.showingCreateSheet) {
                createTeamSheet
            }
        }
    }

    var joinTeamSheet: some View {
        NavigationStack {
            VStack {
                Text("Enter Team Slug")
                    .font(.nunito(.headline))

                TextField(
                    "e.g. 'die-kanten'",
                    text: $teamsVM.joinSlugInput
                )
                .textFieldStyle(.roundedBorder)

                Text(teamsVM.joinError).foregroundColor(IgniteColor.error)
            }
            .padding(25)
            .navigationTitle("Join Team")
            .toolbar {
                // Left: X
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        teamsVM.showingJoinSheet = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                // Right: Check => Join
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await teamsVM.tryJoiningTeam(vm: vm)
                            await teamsVM.reloadTeams(
                                ctx: modelContext
                            )
                        }
                    } label: {
                        if teamsVM.isFetching {
                            ProgressView()
                        } else {
                            Text("Join")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accent)
                    .foregroundStyle(IgniteColor.onAccent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    var createTeamSheet: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Text(
                    """
                    The Notification Template has to contain {{name}} for the user (e.g.: 'OMG \
                    {{name}} ist mies am Gym hitten 🔥).
                    """
                )

                List {
                    Group {
                        TextField("Unique Name", text: $teamsVM.createNameInput)
                        TextField("Details", text: $teamsVM.createDetailsInput)
                        TextField(
                            "Notification Template (optional)",
                            text: $teamsVM.createNotificationTemplate)
                    }
                    .listRowBackground(IgniteColor.surface)
                }
                .igniteListColors()

                Text(teamsVM.createError).foregroundStyle(IgniteColor.error)
            }
            .padding(25)
            .navigationTitle("New Team")
            .toolbar {
                // Left: X
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        teamsVM.showingJoinSheet = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                // Right: Check => Create
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            do {
                                try await teamsVM.tryCreatingTeam(ctx: modelContext, vm: vm)
                                teamsVM.showingCreateSheet = false
                            } catch {
                                teamsVM.createError = error.localizedDescription
                            }
                        }
                    } label: {
                        // show Loading icon waiting for backend
                        if teamsVM.isFetching {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accent)
                    .foregroundStyle(IgniteColor.onAccent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("Teams List") {
    TeamsView()
        .environmentObject(AppVM())
        .environmentObject(TeamsVM())
        .environmentObject(AuthVM())
        .environmentObject(NavigationVM())
}

#Preview("Join Team Sheet") {
    let teamsVM = TeamsVM()
    teamsVM.showingJoinSheet = true

    return TeamsView()
        .environmentObject(AppVM())
        .environmentObject(teamsVM)
        .environmentObject(AuthVM())
        .environmentObject(NavigationVM())
}

#Preview("Create Team Sheet") {
    let teamsVM = TeamsVM()
    teamsVM.showingCreateSheet = true

    return TeamsView()
        .environmentObject(AppVM())
        .environmentObject(teamsVM)
        .environmentObject(AuthVM())
        .environmentObject(NavigationVM())
}

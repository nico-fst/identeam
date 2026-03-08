//
//  DebugInfoView.swift
//  identeam
//
//  Created by Nico Stern on 28.12.25.
//

import SwiftData
import SwiftUI

struct TeamsView: View {
    @EnvironmentObject var teamsVM: TeamsViewModel
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    @Query private var teams: [Team]

    var body: some View {
        NavigationStack {
            List {
                ForEach(teams) { team in
                    NavigationLink {
                        Text("Name: \(team.name)")
                        Text("Details: \(team.details)")
                        Text("Slug: \(team.slug)")

                        Button("Notify Team") {
                            Task {
                                do {
                                    try await TeamService.shared.NotifyTeam(
                                        slug: team.slug
                                    )
                                } catch {
                                    vm.showAlert(
                                        "Error notifying team",
                                        error.localizedDescription
                                    )
                                }
                            }
                        }
                    } label: {
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
            .refreshable {
                await teamsVM.reloadTeams(ctx: modelContext)
            }
            .navigationTitle("Teams")
            .toolbar {
                ToolbarItem {
                    Button(action: {
                        teamsVM.showingCreateSheet.toggle()
                    }) {
                        Label("Create", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $teamsVM.showingJoinSheet) {
                JoinTeamSheet
            }
            .sheet(isPresented: $teamsVM.showingCreateSheet) {
                CreateTeamSheet
            }
        }
    }

    var JoinTeamSheet: some View {
        NavigationStack {
            VStack {
                Text("Enter Team Slug")
                    .font(.headline)
                
                TextField(
                    "e.g. 'die-kanten'",
                    text: $teamsVM.joinSlugInput
                )
                .textFieldStyle(.roundedBorder)
                
                Text(teamsVM.joinError).foregroundColor(.red)
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
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    var CreateTeamSheet: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Text("The name has to be globally unique since it will be used to invite friends.")
                
                List {
                    TextField("Name", text: $teamsVM.createNameInput)
                    TextField("Details", text: $teamsVM.createDetailsInput)
                    
                }
                
                Text(teamsVM.createError).foregroundStyle(.red)
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
                
                // Right: Check => Join
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
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("Teams List") {
    TeamsView()
        .environmentObject(AppViewModel())
        .environmentObject(TeamsViewModel())
        .environmentObject(AuthViewModel())
}

#Preview("Join Team Sheet") {
    let teamsVM = TeamsViewModel()
    teamsVM.showingJoinSheet = true

    return TeamsView()
        .environmentObject(AppViewModel())
        .environmentObject(teamsVM)
        .environmentObject(AuthViewModel())
}

#Preview("Create Team Sheet") {
    let teamsVM = TeamsViewModel()
    teamsVM.showingCreateSheet = true

    return TeamsView()
        .environmentObject(AppViewModel())
        .environmentObject(teamsVM)
        .environmentObject(AuthViewModel())
}

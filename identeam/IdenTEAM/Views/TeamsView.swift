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
                    Button(action: teamsVM.showCreateNewTeamModal) {
                        Label("Create", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $teamsVM.showingJoinSheet) {
                JoinTeamSheet
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
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

                Text(teamsVM.joinError).foregroundColor(.red)
            }
            .navigationTitle("Join existing Team")
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
}

#Preview {
    TeamsView()
        .environmentObject(AppViewModel())
        .environmentObject(TeamsViewModel())
}

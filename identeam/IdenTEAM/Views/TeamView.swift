//
//  TeamView.swift
//  identeam
//
//  Created by Nico Stern on 13.03.26.
//

import SwiftData
import SwiftUI

struct TeamView: View {
    let slug: String
    
    @AppStorage("username") private var username: String = ""
    
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var teamsVM: TeamsViewModel
    @EnvironmentObject var teamVM: TeamViewModel
    @Environment(\.modelContext) private var modelContext

    @Query private var teams: [Team]
    private var team: Team? {
        teams.first(where: { $0.slug == slug })
    }
    
    @Query private var teamWeeks: [TeamWeek]
    private var teamWeek: TeamWeek? {
        teamWeeks.first(where: { $0.slug == slug })
    }

    var body: some View {
        Group {
            if let team {
                List {
                    Section("Info") {
                        TextLabeled("Slug", team.slug)
                        TextLabeled("Details", team.details)
                    }
                    
                    if let teamWeek {
                        Section("Week ⋅ Scored \(teamWeek.identSum) / \(teamWeek.targetSum) Idents ") {
                            ForEach(teamWeek.members.sorted(by: {
                                $0.user.username.lowercased() < $1.user.username.lowercased()
                            })) { member in
                                DisclosureGroup("\(member.user.username) ⋅ \(member.idents.count) / \(member.targetCount) Idents") {
                                    ForEach(member.idents.sorted(by: {
                                        $0.time > $1.time
                                    })) { ident in
                                        let date = ident.time.formatted(
                                            .dateTime
                                                .weekday(.abbreviated)
                                                .day()
                                                .month(.wide)
                                                .hour()
                                                .minute()
                                        )
                                        
                                        VStack(alignment: .leading) {
                                            Text(ident.userText)
                                            Text(date)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Section("TeamWeek") {
                            Text("No Info...").opacity(0.25)
                        }
                    }

                    Section("My Target") {
                        Picker("Target", selection: $teamVM.selectedTargetCount) {
                            ForEach(1...7, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.menu)

                        Button("Set Target") {
                            Task {
                                await teamVM.trySettingTarget(
                                    slug: team.slug,
                                    vm: vm,
                                    ctx: modelContext,
                                    teamsVM: teamsVM
                                )
                            }
                        }
                    }
                    
                    if (teamWeek?.members.contains(where: {
                        $0.user.username == username && $0.targetCount > 0
                    }) ?? false) {
                        Section("New Ident") {
                            TextField("Tell your members about your ident...", text: $teamVM.createIdentUserText)
                            
                            Button("Create Ident") {
                                Task {
                                    await teamVM.tryCreatingIdent(
                                        slug: slug,
                                        vm: vm,
                                        ctx: modelContext,
                                        teamsVM: teamsVM
                                    )
                                }
                            }
                        }
                    }
                    
                    Section("Debugging") {
                        Button("Notify Team") {
                            Task {
                                do {
                                    try await TeamService.shared.NotifyTeam(slug: team.slug)
                                } catch {
                                    vm.showAlert(
                                        "Error notifying team",
                                        error.localizedDescription
                                    )
                                }
                            }
                        }
                    }
                    .navigationTitle(team.name)
                }.listStyle(InsetGroupedListStyle())
            } else {
                ContentUnavailableView(
                    "Team not found",
                    systemImage: "person.2.slash"
                )
            }
        }
        .refreshable {
            if let team {
                await teamsVM.reloadTeamWeek(slug: team.slug, vm: vm, ctx: modelContext)
            }
        }
        .task {
            if let team {
                await teamsVM.reloadTeamWeek(slug: team.slug, vm: vm, ctx: modelContext)
            }
        }
    }
}

private struct TeamView_PreviewContainer: View {
    let container: ModelContainer

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        self.container = try! ModelContainer(for: Team.self, TeamWeek.self, configurations: config)

        // Insert mock data into the in-memory context
        let mockTeam = Team(name: "Die Kanten", slug: "die-kanten", details: "Mock Team for Preview")
        let mockWeek = TeamWeek(slug: "die-kanten", targetSum: 10, identSum: 3, members: [])
        container.mainContext.insert(mockTeam)
        container.mainContext.insert(mockWeek)
    }

    var body: some View {
        TeamView(slug: "die-kanten")
            .environmentObject(AppViewModel())
            .environmentObject(TeamsViewModel())
            .environmentObject(TeamViewModel())
            .modelContainer(container)
    }
}

#Preview("TeamView with Mock Data") {
    TeamView_PreviewContainer()
}

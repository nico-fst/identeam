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

    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var teamsVM: TeamsViewModel
    @Environment(\.modelContext) private var modelContext
    
    @Query private var teams: [Team]
    @Query private var teamWeeks: [TeamWeek]

    private var team: Team? {
        teams.first(where: { $0.slug == slug })
    }
    
    private var teamWeek: TeamWeek? {
        teamWeeks.first(where: { $0.slug == slug })
    }

    var body: some View {
        Group {
            if let team {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name: \(team.name)")
                        Text("Details: \(team.details)")
                        Text("Slug: \(team.slug)")
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Gespeicherte TeamWeeks: \(teamWeeks.count)")
                            Text("Aktueller Slug: \(slug)")
                            Text("Gefundene TeamWeek: \(teamWeek == nil ? "nein" : "ja")")
                            Text("Members: \(teamWeek?.members.count ?? 0)")
                        }
                        
                        if let teamWeek {
                            Text("Ziel: \(teamWeek.targetSum)")
                            Text("#Idents: \(teamWeek.identSum)")
                            Text("=> \(teamWeek.identSum)/\(teamWeek.targetSum)")
                            
                            ForEach(teamWeek.members) { member in
                                Spacer()
                                Text("\(member.user.username) hat \(member.idents.count) von \(member.targetCount) Idents gescored.")
                            }
                        }
                        
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
                    .padding()
                    .navigationTitle(team.name)
                }
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

#Preview {
    TeamView(slug: "die-kanten")
}

//
//  TeamWheel.swift
//  identeam
//
//  Created by Nico Stern on 12.05.26.
//

import SwiftUI
import SwiftData

struct TeamWheel: View {
    let textColor: Color
    @Binding var selectedTeamSlug: String?
    @Query(sort: \Team.slug) private var teams: [Team]
    
    var body: some View {
        Picker("Team", selection: $selectedTeamSlug) {
            if !teams.isEmpty {
                ForEach(teams, id: \.slug) { team in
                    Text(team.name).tag(Optional(team.slug))
                        .foregroundStyle(textColor)
                }
            } else {
                Text("Join a team first!").tag(String?.none)
                    .foregroundStyle(.white)
                Text("Then you may select one").tag(String?.none)
                    .foregroundStyle(.white)
            }
        }
        .pickerStyle(.wheel)
        .clipped()
        .onAppear {
            if selectedTeamSlug == nil {
                selectedTeamSlug = teams.first?.slug
            }
        }
        .onChange(of: teams.map(\.slug)) { _, slugs in
            if selectedTeamSlug == nil || !slugs.contains(selectedTeamSlug ?? "") {
                selectedTeamSlug = slugs.first
            }
        }
    }
}

//
//  AuthViewModel.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Combine
import Foundation
import SwiftData
import SwiftUI

class TeamsViewModel: ObservableObject {
    @Published var showingJoinSheet: Bool = false
    @Published var joinSlugInput: String = ""
    @Published var joinError: String = ""

    @Published var isFetching: Bool = false

    func reloadTeams(ctx modelContext: ModelContext) async {
        do {
            //  delete old teams
            let oldTeams = try modelContext.fetch(FetchDescriptor<Team>())
            for team in oldTeams { modelContext.delete(team) }

            // save new teams
            let newTeams: [Team] = try await TeamService.shared.getMyTeams()
            for team in newTeams { modelContext.insert(team) }
        } catch {
            print("ERROR replacing cached Kuotes with fetched ones: ", error)
        }
    }

    func clearTeams(ctx modelContext: ModelContext) async {
        do {
            //  delete old teams
            let oldTeams = try modelContext.fetch(FetchDescriptor<Team>())
            for team in oldTeams { modelContext.delete(team) }
        } catch {
            print("ERROR deleting all teams: ", error)
        }
    }

    // allow only letters and "-"
    var isValidJoinSlug: Bool {
        let pattern = "^[A-Za-z-]+$"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: joinSlugInput.utf16.count)
        return regex.firstMatch(in: joinSlugInput, range: range) != nil
    }

    func tryJoiningTeam(vm: AppViewModel) async {
        isFetching = true
        defer { isFetching = false }

        guard !joinSlugInput.isEmpty else {
            joinError = "No Join Slug, no Team..."
            return
        }
        guard isValidJoinSlug else {
            joinError =
                "Only A-Z, a-z, and - without spaces as Slug are allowed."
            return
        }

        do {
            try await Task.sleep(nanoseconds: 500_000_000)  // debugging ProgressView() in ToolbarItem
            let resp = try await TeamService.shared.joinTeam(
                slug: joinSlugInput
            )

            vm.toastMessage =
                "Yay, you joined '\(resp.team.name)'"
            showingJoinSheet = false
        } catch {
            joinError = error.localizedDescription
        }
    }

    func tryLeavingTeam(ctx: ModelContext, vm: AppViewModel, slug: String) async
    {
        isFetching = true
        defer { isFetching = false }

        guard !slug.isEmpty else {
            vm.showAlert("Error leaving Team", "No Team specified")
            return
        }

        do {
            let resp = try await TeamService.shared.leaveTeam(slug: slug)
            await reloadTeams(ctx: ctx)
            vm.toastMessage =
                "You just left '\(resp.team.name)' (heartbreaking)"
        } catch {
            vm.showAlert("Error leaving Team", error.localizedDescription)
        }
    }

    func showCreateNewTeamModal() {
        return  // TODO
    }
}

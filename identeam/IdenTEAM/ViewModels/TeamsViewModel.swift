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
    
    @Published var showingCreateSheet: Bool = false
    @Published var createNameInput: String = ""
    @Published var createDetailsInput: String = ""
    @Published var createNotificationTemplate: String = ""
    @Published var createError: String = ""
    
    // TeamWeek
    let selectedWeek = Date()
    
    @Published var isFetching: Bool = false // used for creating, joining
    
    func reloadTeams(ctx modelContext: ModelContext) async {
        do {
            //  delete old teams
            let oldTeams = try modelContext.fetch(FetchDescriptor<Team>())
            for team in oldTeams { modelContext.delete(team) }
            
            // save new teams
            let newTeams: [Team] = try await TeamRService.shared.fetchMyTeams()
            for team in newTeams { modelContext.insert(team) }
        } catch {
            print("ERROR replacing cached Teams with fetched ones: ", error)
        }
    }
    
    @MainActor
    func reloadTeamWeek(slug: String, vm: AppViewModel, ctx modelContext: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<TeamWeek>(
                predicate: #Predicate<TeamWeek> { teamWeek in
                    teamWeek.slug == slug
                }
            )
            
            let oldTeamWeek: TeamWeek? = try modelContext.fetch(descriptor).first
            if let team = oldTeamWeek {
                print("Deleting old teamWeek with slug:", team.slug)
                modelContext.delete(team)
            }

            let newTeamWeek: TeamWeek = try await TeamRService.shared.fetchTeamWeek(
                slug: slug,
                date: selectedWeek
            )
            modelContext.insert(newTeamWeek)
            try modelContext.save()

            vm.toastMessage = "Refreshed TeamWeek"
        } catch is CancellationError {
            return
        } catch {
            vm.showAlert("ERROR fetching TeamWeek", error.localizedDescription)
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
    func isValidSlug(slug: String) -> Bool {
        let pattern = "^[A-Za-z-]+$"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: slug.utf16.count)
        
        return regex.firstMatch(in: slug, range: range) != nil
    }
    
    func tryJoiningTeam(vm: AppViewModel) async {
        isFetching = true
        defer { isFetching = false }
        
        guard !joinSlugInput.isEmpty else {
            joinError = "No Join Slug, no Team..."
            return
        }
        guard isValidSlug(slug: joinSlugInput) else {
            joinError =
            "Only A-Z, a-z, and - without spaces as Slug are allowed."
            return
        }
        
        do {
            try await Task.sleep(nanoseconds: 500_000_000)  // debugging ProgressView() in ToolbarItem
            let resp = try await TeamRService.shared.joinTeam(
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
            let resp = try await TeamRService.shared.leaveTeam(slug: slug)
            await reloadTeams(ctx: ctx)
            vm.toastMessage =
            "You just left '\(resp.team.name)' (heartbreaking)"
        } catch {
            vm.showAlert("Error leaving Team", error.localizedDescription)
        }
    }
    
    func tryCreatingTeam(ctx: ModelContext, vm: AppViewModel) async throws {
        isFetching = true
        defer { isFetching = false }
        
        guard !createNameInput.isEmpty, !createDetailsInput.isEmpty else {
            createError = "Name  and Details must be specified"
            return
        }
        
        do {
            let resp = try await TeamRService.shared.createTeam(
                name: createNameInput,
                details: createDetailsInput,
                notificationTemplate: createNotificationTemplate)
            await reloadTeams(ctx: ctx)
            vm.toastMessage = "Let's go! You just created team '\(resp.name)'"
        } catch {
            throw error
        }
    }
}

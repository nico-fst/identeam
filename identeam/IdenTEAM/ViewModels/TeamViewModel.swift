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

class TeamViewModel: ObservableObject {
    @Published var createIdentUserText: String = ""
    @Published var selectedTargetCount: Int = 0
    
    func tryCreatingIdent(
        slug: String,
        vm: AppViewModel,
        ctx: ModelContext,
        teamsVM: TeamsViewModel
    ) async {
        guard !createIdentUserText.isEmpty else {
            vm.showAlert("Error creating Ident", "You must provide an UserText")
            return
        }

        do {
            try await TeamService.shared.createIdent(slug: slug, text: createIdentUserText)
        } catch {
            vm.showAlert("Error creating Ident", error.localizedDescription)
            return
        }
        
        vm.toastMessage = "Ident created"
        createIdentUserText = ""
        
        await teamsVM.reloadTeamWeek(slug: slug, vm: vm, ctx: ctx)
    }

    func trySettingTarget(
        slug: String,
        vm: AppViewModel,
        ctx: ModelContext,
        teamsVM: TeamsViewModel
    ) async {
        guard selectedTargetCount != 0 else {
            vm.showAlert("Error setting target", "You must select a value first")
            return
        }

        do {
            try await TeamService.shared.setTarget(
                slug: slug,
                dateStart: Date(),
                count: selectedTargetCount
            )
        } catch {
            vm.showAlert("Error setting Target", error.localizedDescription)
            return
        }

        vm.toastMessage = "Target set"

        await teamsVM.reloadTeamWeek(slug: slug, vm: vm, ctx: ctx)
    }
}

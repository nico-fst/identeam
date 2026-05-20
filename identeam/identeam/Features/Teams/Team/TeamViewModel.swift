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
    @Published var showSettingTarget = false
    
    func tryCreatingIdent(
        slug: String,
        vm: AppViewModel,
        ctx: ModelContext,
        teamsVM: TeamsViewModel
    ) async {
        let trimmedUserText = createIdentUserText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserText.isEmpty else {
            vm.showAlert("Error creating Ident", "You must provide an UserText")
            return
        }

        do {
            _ = try await IdentAPI.shared.createIdent(slug: slug, text: trimmedUserText)
        } catch {
            vm.showAlert("Error creating Ident", error.localizedDescription)
            return
        }
        
        vm.toastMessage = "Ident created"
        createIdentUserText = ""
        await teamsVM.reloadTeamWeek(slug: slug, vm: vm, ctx: ctx)
    }
}

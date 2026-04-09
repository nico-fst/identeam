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
    
    func tryCreatingIdent(slug: String, vm: AppViewModel, ctx: ModelContext, teamsVM: TeamsViewModel) async {
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
}

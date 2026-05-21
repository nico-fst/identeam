//
//  IdentingViewModel.swift
//  identeam
//
//  Created by Nico Stern on 13.05.26.
//

import Foundation
import Combine
import SwiftData

@MainActor
class IdentingViewModel: ObservableObject {
    @Published var createIdentUserText: String = ""
    @Published var selectedTeamSlug: String?
    
    @Published var isUploadingImage = false
    @Published var uploadError: String?
    
    @Published var isSettingTarget = false
    
    func tryCreatingIdentWithImage(
        image: IdentifiableImage,
        vm: AppViewModel,
        ctx: ModelContext,
        teamsVM: TeamsViewModel
    ) async -> Bool {
        guard let slug = selectedTeamSlug else {
            vm.showAlert("Error creating Ident", "You must select a team")
            return false
        }

        let trimmedUserText = createIdentUserText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserText.isEmpty else {
            uploadError = "Write something about your ident first :)"
            return false
        }

        isUploadingImage = true
        uploadError = nil
        defer { isUploadingImage = false }

        do {
            let ident = try await IdentAPI.shared.createIdent(slug: slug, text: trimmedUserText)
            try await IdentAPI.shared.storeIdentImage(
                slug: slug,
                identID: String(ident.id),
                imageData: image.imageData,
                contentType: "image/jpeg"
            )
            
            vm.toastMessage = "Ident created"
            createIdentUserText = ""
            await teamsVM.reloadTeamWeek(slug: slug, vm: vm, ctx: ctx)
            return true
        } catch TeamError.targetNotSet {
            isSettingTarget = true
        } catch {
            uploadError = error.localizedDescription
            return false
        }
        
        return false
    }
}


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
    private let now: () -> Date

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
    }

    @Published var createIdentUserText: String = ""
    @Published var selectedTeamSlug: String?
    
    @Published var isUploadingImage = false
    @Published var uploadError: String?
    
    @Published var isSettingTarget = false
    @Published var showMissingTargetWarning = false
    private var missingTargetConfirmation: CheckedContinuation<Bool, Never>?

    func resolveMissingTargetWarning(continueUpload: Bool) {
        let confirmation = missingTargetConfirmation
        missingTargetConfirmation = nil
        showMissingTargetWarning = false
        confirmation?.resume(returning: continueUpload)
    }

    private func confirmUploadWithoutTarget() async -> Bool {
        await withCheckedContinuation { continuation in
            missingTargetConfirmation = continuation
            showMissingTargetWarning = true
        }
    }
    
    func tryCreatingIdentWithImage(
        image: IdentifiableImage,
        vm: AppViewModel,
        ctx: ModelContext,
        teamsVM: TeamsViewModel
    ) async -> Bool {
        guard !isUploadingImage else { return false }
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
            let identDate = now()
            let ident: IdentDTO
            do {
                ident = try await IdentAPI.shared.createIdent(slug: slug, text: trimmedUserText, date: identDate)
            } catch TeamError.targetNotSet {
                if ReminderSchedulePlanner.canSetTargetWeek(identDate, now: now()) {
                    isSettingTarget = true
                    return false
                }
                guard await confirmUploadWithoutTarget() else { return false }
                ident = try await IdentAPI.shared.createIdent(
                    slug: slug, text: trimmedUserText, date: identDate, allowWithoutTarget: true
                )
            }
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
        } catch {
            uploadError = error.localizedDescription
            return false
        }
    }
}


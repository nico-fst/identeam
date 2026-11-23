import Combine
import Foundation
import SwiftData
import SwiftUI

class TeamWeekVM: ObservableObject {
    @Published var createIdentUserText: String = ""
    @Published var showSettingTarget = false

    @Published var selectedIdent: Ident?

    @Published var commentInput: String = ""
    @Published var commentError: String = ""

    @Published var remindButtonDisabled = false
    @Published var remindDisabledUntil: Date?

    @Published var now = Date()
    @Published var referenceDate: Date = AppCalendar.startOfWeek(containing: Date())

    var weekStart: Date {
        AppCalendar.startOfWeek(containing: referenceDate)
    }

    var remindCooldownRemaining: Int {
        guard let remindDisabledUntil else { return 0 }
        return max(0, Int(ceil(remindDisabledUntil.timeIntervalSince(now))))
    }

    func changeWeek(by days: Int) {
        referenceDate = AppCalendar.calendar.date(byAdding: .day, value: days, to: referenceDate)!
    }

    func tryRemindingTeam(slug: String, vm: AppVM) async {
        do {
            try await TeamAPI.shared.remindTeam(slug: slug)

            remindDisabledUntil = Date().addingTimeInterval(9)
            remindButtonDisabled = true
            now = Date()

            Task { @MainActor in
                while remindCooldownRemaining > 1 {
                    now = Date()
                    try? await Task.sleep(for: .seconds(1))
                }

                remindButtonDisabled = false
                remindDisabledUntil = nil
                now = Date()
            }
        } catch {
            vm.showAlert(
                "Error reminding team",
                error.localizedDescription
            )
        }
    }
    var remindButtonTitle: String {
        guard remindCooldownRemaining > 0 else { return "Remind Team" }
        return "Remind Team ⋅ \(remindCooldownRemaining)s"
    }

    // Legacy, unused (before photos)
    func tryCreatingIdent(
        slug: String,
        vm: AppVM,
        ctx: ModelContext,
        teamsVM: TeamsVM
    ) async {
        let trimmedUserText = createIdentUserText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserText.isEmpty else {
            vm.showAlert("Error creating Ident", "You must provide an UserText")
            return
        }

        do {
            let ident = try await IdentAPI.shared.createIdent(slug: slug, text: trimmedUserText)
            await teamsVM.reloadTeamWeek(slug: slug, weekStart: ident.time, vm: vm, ctx: ctx)
        } catch {
            vm.showAlert("Error creating Ident", error.localizedDescription)
            return
        }

        vm.toastMessage = "Ident created"
        createIdentUserText = ""
    }

    func tryCommenting(
        slug: String,
        vm: AppVM,
        ctx: ModelContext,
        teamsVM: TeamsVM
    ) async {
        let trimmedCommentText = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommentText.isEmpty else {
            commentError = "Write something first..."
            return
        }
        guard let selectedIdent else {
            commentError = "ERROR: No Ident selected"
            return
        }

        let identID = selectedIdent.remoteID
        let weekStart = AppCalendar.startOfWeek(containing: selectedIdent.time)
        do {
            _ = try await CommentAPI.shared.comment(
                text: trimmedCommentText,
                slug: slug,
                identID: identID
            )
        } catch {
            commentError = error.localizedDescription
            return
        }

        vm.toastMessage = "Commented"
        commentInput = ""
        commentError = ""
        let reloadedTeamWeek = await teamsVM.reloadTeamWeek(
            slug: slug, weekStart: weekStart, vm: vm, ctx: ctx)
        self.selectedIdent = reloadedTeamWeek?  // temporary workaround for seeing new comment
            .members
            .flatMap(\.idents)
            .first { $0.remoteID == identID }
    }

    func tryDeletingComment(
        commentID: Int,
        slug: String,
        vm: AppVM,
        ctx: ModelContext,
        teamsVM: TeamsVM
    ) async {
        guard let selectedIdent else {
            commentError = "ERROR: No Ident selected"
            return
        }

        let identID = selectedIdent.remoteID
        let weekStart = AppCalendar.startOfWeek(containing: selectedIdent.time)
        do {
            _ = try await CommentAPI.shared.uncomment(
                slug: slug,
                identID: identID,
                commentID: commentID
            )
        } catch {
            commentError = error.localizedDescription
            return
        }

        vm.toastMessage = "Comment deleted"
        commentError = ""
        let reloadedTeamWeek = await teamsVM.reloadTeamWeek(
            slug: slug, weekStart: weekStart, vm: vm, ctx: ctx)
        self.selectedIdent = reloadedTeamWeek?
            .members
            .flatMap(\.idents)
            .first { $0.remoteID == identID }
    }
}

import Combine
import Foundation
import SwiftData

@MainActor
final class TargetPickerViewModel: ObservableObject {
    @Published var referenceDate: Date
    @Published var selectedDays: Set<Date>
    @Published var isLoading = true
    @Published var hasLoaded = false
    @Published var isSettingTarget = false
    @Published var settingError = ""

    init(referenceDate: Date, initialSelectedDays: [Date] = []) {
        self.referenceDate = max(
            AppCalendar.startOfWeek(containing: referenceDate),
            TargetPlanning.firstPlannableWeek()
        )
        selectedDays = Set(initialSelectedDays)
    }

    func changeWeek(by days: Int) {
        isLoading = true
        hasLoaded = false
        selectedDays = []
        referenceDate = AppCalendar.calendar.date(byAdding: .day, value: days, to: referenceDate)!
    }

    func loadTargetDays(slug: String, userID: String) async {
        isLoading = true
        hasLoaded = false
        settingError = ""
        do {
            let week = try await TeamAPI.shared.fetchTeamWeek(slug: slug, date: referenceDate)
            guard !Task.isCancelled else { return }
            selectedDays = Set(week.members.first { $0.user.userID == userID }?.targetDays ?? [])
            isLoading = false
            hasLoaded = true
        } catch {
            guard !Task.isCancelled else { return }
            isLoading = false
            settingError = error.localizedDescription
        }
    }

    func trySettingTarget(
        slug: String,
        vm: AppViewModel,
        ctx: ModelContext,
        userID: String,
    ) async -> Bool {
        var notificationsScheduled = false

        settingError = ""
        isSettingTarget = true
        defer { isSettingTarget = false }

        do {
            try await TeamAPI.shared.setTarget(
                slug: slug,
                dateStart: referenceDate,
                targetDays: Array(selectedDays)
            )

            // schedule notifications

            let teamName = try? ctx.fetch(
                FetchDescriptor<Team>(
                    predicate: #Predicate<Team> { team in
                        team.slug == slug
                    }
                )
            ).first?.name

            if try await refreshLocalNotifications(
                slug: slug,
                teamName: teamName ?? slug,
                userID: userID,
                dateStart: referenceDate
            ) > 0 {
                notificationsScheduled = true
            }
        } catch {
            settingError = error.localizedDescription
            return false
        }

        vm.toastMessage = "Target set\(notificationsScheduled ? " ⋅ Notifications scheduled" : "")"

        return true
    }
}

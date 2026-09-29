import SwiftUI

struct TeamWeekActionsSection: View {
    let slug: String
    let hasLoadedFreshTeamWeek: Bool
    @EnvironmentObject private var vm: AppVM
    @EnvironmentObject private var teamVM: TeamWeekVM

    var body: some View {
        Section("Actions") {
            Button {
                Task {
                    await teamVM.tryRemindingTeam(slug: slug, vm: vm)
                }
            } label: {
                Label(
                    teamVM.remindButtonTitle,
                    systemImage: teamVM.remindButtonDisabled ? "bell.fill" : "bell"
                )
            }
            .disabled(teamVM.remindButtonDisabled || !hasLoadedFreshTeamWeek)
            .opacity(teamVM.remindButtonDisabled ? 0.3 : 1)

            Button {
                teamVM.showSettingTarget = true
            } label: {
                Label(
                    "Plan Targets",
                    systemImage: "target"
                )
            }
            .disabled(!hasLoadedFreshTeamWeek)
        }
    }
}

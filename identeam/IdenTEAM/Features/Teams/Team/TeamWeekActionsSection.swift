import SwiftUI

struct TeamWeekActionsSection: View {
    let slug: String
    let hasLoadedFreshTeamWeek: Bool
    @EnvironmentObject private var vm: AppViewModel
    @EnvironmentObject private var teamVM: TeamWeekViewModel

    var body: some View {
        Section("Actions") {
            Button() {
                Task {
                    await teamVM.tryRemindingTeam(slug: slug, vm: vm)
                }
            } label: {
                Label(
                    teamVM.remindButtonTitle,
                    systemImage: teamVM.remindButtonDisabled ? "bell.fill" : "bell"
                )
            }
            .disabled(teamVM.remindButtonDisabled)
            .opacity(teamVM.remindButtonDisabled ? 0.3 : 1)

            if hasLoadedFreshTeamWeek {
                Button() {
                    teamVM.showSettingTarget = true
                } label: {
                    Label(
                        "Plan Targets",
                        systemImage: "target"
                    )
                }
            } else {
                ProgressView()
            }
        }

    }
}

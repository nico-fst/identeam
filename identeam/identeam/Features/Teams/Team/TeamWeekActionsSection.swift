import SwiftUI

struct TeamWeekActionsSection: View {
    let slug: String
    let hasLoadedFreshTeamWeek: Bool
    let dark: Bool
    @EnvironmentObject private var vm: AppVM
    @EnvironmentObject private var teamVM: TeamWeekVM

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        Task { await teamVM.tryRemindingTeam(slug: slug, vm: vm) }
                    } label: {
                        Label(
                            teamVM.remindButtonTitle,
                            systemImage: teamVM.remindButtonDisabled ? "bell.fill" : "bell")
                    }
                    .disabled(teamVM.remindButtonDisabled || !hasLoadedFreshTeamWeek)

                    Button {
                        teamVM.showSettingTarget = true
                    } label: {
                        Label("Ziel planen", systemImage: "target")
                    }
                    .disabled(!hasLoadedFreshTeamWeek)
                }
                .font(TeamWeekStyle.font(14))
                .buttonStyle(.glass)
                .tint(dark ? .white : AppColor.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .modifier(AppGlass(dark: dark))
            } header: {
                Text("Aktionen")
                    .font(TeamWeekStyle.font(19, heavy: true))
                    .foregroundStyle(dark ? AppColor.Palette.cream : AppColor.Palette.ink)
            }
        }
    }
}

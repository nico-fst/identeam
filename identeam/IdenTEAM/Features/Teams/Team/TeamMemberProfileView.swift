import SwiftData
import SwiftUI

/// Profile sheet shared by member links in the week grid, legend and summary cards.
/// The selected user's month reuses the app/widget calendar; month loading belongs to this sheet.
struct TeamMemberProfileView: View {
    let user: User
    let slug: String
    let month: Date
    let viewerID: String
    let referenceDate: Date
    var showsMonth = true

    @Query private var teamWeeks: [TeamWeek]
    @State private var isLoadingMonth = false
    @EnvironmentObject private var teamsVM: TeamsVM
    @EnvironmentObject private var vm: AppVM
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var monthWeeks: [TeamWeek] {
        let starts = AppCalendar.weekStartsInMonth(containing: month)
        return teamWeeks.filter { $0.slug == slug && starts.contains($0.weekStart) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    UserAvatarView(image: RemoteImageReference(item: user.avatar))
                        .frame(width: 100, height: 100)
                    Text(user.nickname).font(.nunito(.title))
                        .multilineTextAlignment(.center)
                    Text("@\(user.username)").font(.nunito(.subheadline))
                        .foregroundStyle(AppColor.muted)
                }
                .frame(maxWidth: .infinity)

                if showsMonth {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(user.userID == viewerID ? "Dein Monat" : "Monatsübersicht")
                            .font(.nunito(.headline))
                        Text(month, format: .dateTime.month(.wide).year())
                            .font(.nunito(.subheadline)).foregroundStyle(AppColor.muted)
                        monthContent
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .modifier(AppGlass(dark: colorScheme == .dark))
                    }
                }
            }
            .padding(20)
        }
        .appColors()
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Schließen", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
            }
        }
        .task(id: month) { await loadMonth() }
    }

    @ViewBuilder private var monthContent: some View {
        if monthWeeks.count == AppCalendar.weekStartsInMonth(containing: month).count {
            LastMonthView(
                month: month,
                personalWeeks: monthWeeks.compactMap {
                    PersonalWeek(teamWeek: $0, userID: user.userID)
                },
                referenceDate: referenceDate)
        } else if isLoadingMonth {
            ProgressView("Monat wird geladen …").padding()
        } else {
            VStack(spacing: 12) {
                Text("Monat konnte nicht geladen werden.").foregroundStyle(AppColor.muted)
                Button("Erneut laden") { Task { await loadMonth() } }
            }
        }
    }

    @MainActor private func loadMonth() async {
        guard showsMonth, !isLoadingMonth else { return }
        isLoadingMonth = true
        defer { isLoadingMonth = false }
        let cachedStarts = Set(monthWeeks.map(\.weekStart))
        for start in AppCalendar.weekStartsInMonth(containing: month)
        where !cachedStarts.contains(start) {
            guard !Task.isCancelled else { return }
            guard
                await teamsVM.reloadTeamWeek(slug: slug, weekStart: start, vm: vm, ctx: context)
                    != nil
            else {
                return
            }
        }
    }
}

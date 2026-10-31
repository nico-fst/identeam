#if DEBUG
    import SwiftData
    import SwiftUI

    /// A single frozen fixture per progress stage, with no menus or account preference writes.
    struct TeamWeekScreenPreview: View {
        private let container: ModelContainer
        private let configuration: TeamWeekPreviewConfiguration
        @StateObject private var teamVM: TeamWeekVM

        init(stage: Int) {
            let value = TeamWeekPreviewFixtures.make(stage: stage)
            configuration = TeamWeekPreviewConfiguration(
                userID: value.currentUserID, now: value.now)
            container = try! ModelContainer(
                for: SharedModelConfig.schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            container.mainContext.insert(
                Team(name: "Die Kanten", slug: "__debug__", details: "Offline Preview"))
            let history = (-3...0).map {
                AppCalendar.calendar.date(byAdding: .weekOfYear, value: $0, to: value.weekStart)!
            }
            for start in Set(AppCalendar.weekStartsInMonth(containing: value.weekStart) + history) {
                let week = TeamWeekPreviewFixtures.make(stage: stage, weekStart: start)
                container.mainContext.insert(Self.model(from: week))
            }
            let vm = TeamWeekVM()
            vm.referenceDate = value.weekStart
            _teamVM = StateObject(wrappedValue: vm)
        }

        var body: some View {
            NavigationStack {
                TeamWeekView(
                    slug: "__debug__", teamVM: teamVM, preview: configuration,
                    referenceDate: configuration.now)
            }
            .environmentObject(AppVM())
            .environmentObject(TeamsVM())
            .modelContainer(container)
            .appColors()
        }

        private static func model(from week: TeamWeekPresentation) -> TeamWeek {
            let members = week.members.enumerated().map { index, member in
                let avatar = placeholder("avatar-\(member.id)", kind: .avatar, now: week.now)
                let user = User(
                    userID: member.id, email: "", nickname: member.name,
                    username: member.name.lowercased(), avatar: avatar)
                let idents = member.idents.enumerated().map { number, entry in
                    Ident(
                        remoteID: index * 10 + number + 1, time: entry.time,
                        userText: "Preview · \(member.name)",
                        image: placeholder("ident-\(entry.id)", kind: .identImage, now: week.now),
                        comments: [])
                }
                return TeamMember(
                    user: user, targetDays: member.targets.map(AppCalendar.dateString),
                    idents: idents)
            }
            return TeamWeek(
                slug: "__debug__", weekStart: week.weekStart, targetSum: UInt(week.target),
                identSum: UInt(week.completed), members: members, teamStreak: UInt(week.streak))
        }

        private static func placeholder(_ key: String, kind: S3ItemKind, now: Date) -> S3Item {
            S3Item(
                url: URL(fileURLWithPath: "/team-week-preview/\(key).png"), key: key,
                expiresAt: now.addingTimeInterval(365 * 86400), kind: kind)
        }
    }

#endif

#if DEBUG
    import SwiftData
    import SwiftUI
    /// The actual screen, backed by a private in-memory store and a frozen viewer/clock.
    struct TeamWeekDesignPreview: View {
        private let container: ModelContainer
        private let configuration: TeamWeekPreviewConfiguration
        @StateObject private var teamVM: TeamWeekVM
        @StateObject private var vm = AppVM()
        @StateObject private var teamsVM = TeamsVM()

        init(
            scenario: TeamWeekPresentation.Scenario? = nil, streak: Int? = nil,
            detailed: Bool? = nil, card: Int = 0
        ) {
            let arguments = ProcessInfo.processInfo.arguments
            let resolvedScenario =
                scenario ?? Self.argument("--scenario", in: arguments)
                .flatMap(TeamWeekPresentation.Scenario.init(rawValue:)) ?? .nearlyFinished
            let resolvedStreak =
                streak ?? Self.argument("--streak", in: arguments).flatMap(Int.init) ?? 3
            let value = TeamWeekPreviewFixtures.make(
                scenario: resolvedScenario, streak: resolvedStreak)
            self.configuration = TeamWeekPreviewConfiguration(
                userID: value.currentUserID, now: value.now,
                detailed: detailed ?? arguments.contains("--detailed"), card: card)
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(
                for: SharedModelConfig.schema, configurations: configuration)
            container.mainContext.insert(
                Team(name: "Die Kanten", slug: "__debug__", details: "Offline Xcode Preview"))
            let history = (-3...0).map {
                AppCalendar.calendar.date(byAdding: .weekOfYear, value: $0, to: value.weekStart)!
            }
            let starts = Set(AppCalendar.weekStartsInMonth(containing: value.weekStart) + history)
            for start in starts {
                let week = TeamWeekPreviewFixtures.make(
                    scenario: resolvedScenario, streak: resolvedStreak, weekStart: start)
                container.mainContext.insert(Self.model(from: week))
            }
            try! container.mainContext.save()
            let teamVM = TeamWeekVM()
            teamVM.referenceDate = value.weekStart
            _teamVM = StateObject(wrappedValue: teamVM)
        }

        var body: some View {
            NavigationStack {
                TeamWeekView(
                    slug: "__debug__", teamVM: teamVM, preview: configuration,
                    referenceDate: configuration.now)
            }
            .environmentObject(vm)
            .environmentObject(teamsVM)
            .modelContainer(container)
            .appColors()
            .alert(item: $vm.alert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message))
            }
        }

        private static func argument(_ key: String, in arguments: [String]) -> String? {
            guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1)
            else { return nil }
            return arguments[index + 1]
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

    /// Rebuild only when a fixture option changes; ordinary interactions retain their state.
    private struct ConfigurableTeamWeekPreview: View {
        @State private var scenario: TeamWeekPresentation.Scenario = .nearlyFinished
        @State private var streak = 3
        @State private var card = 0

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Menu("Infobox") {
                        Picker("Infobox", selection: $scenario) {
                            Text("Ziel setzen").tag(TeamWeekPresentation.Scenario.setGoal)
                            Text("Neue Woche").tag(TeamWeekPresentation.Scenario.newWeek)
                            Text("Team fast fertig").tag(
                                TeamWeekPresentation.Scenario.nearlyFinished)
                            Text("Die anderen fast fertig").tag(
                                TeamWeekPresentation.Scenario.catchingUp)
                            Text("Team hinterher").tag(TeamWeekPresentation.Scenario.behind)
                            Text("Du bist auf Kurs").tag(
                                TeamWeekPresentation.Scenario.personallyOnTrack)
                            Text("Team auf Kurs").tag(TeamWeekPresentation.Scenario.teamOnTrack)
                        }
                    }
                    HStack(spacing: 4) {
                        Button {
                            streak -= 1
                        } label: {
                            Image(systemName: "minus")
                        }
                        .disabled(streak == 0)
                        Text("Streak: \(streak)").monospacedDigit()
                        Button {
                            streak += 1
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(streak == 12)
                    }
                    .fixedSize()
                    Menu("Karte") {
                        Picker("Karte", selection: $card) {
                            Text("Infobox").tag(0)
                            Text("Flammen-Trophäe").tag(1)
                            Text("Level-Up").tag(2)
                            Text("Streak-Kette").tag(3)
                            Text("Meilenstein").tag(4)
                        }
                    }
                }
                .font(.caption.bold())
                .lineLimit(1)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(AppColor.Palette.cream)
                TeamWeekDesignPreview(
                    scenario: scenario, streak: streak, detailed: false, card: card
                )
                .id("\(scenario.rawValue)-\(streak)-\(card)")
            }
        }
    }

    #Preview("Konfigurierbar · Alle Kombinationen") { ConfigurableTeamWeekPreview() }

    #Preview("Infobox · Ziellos") { TeamWeekDesignPreview(scenario: .setGoal, streak: 0) }
    #Preview("Infobox · Neue Woche") { TeamWeekDesignPreview(scenario: .newWeek, streak: 1) }
    #Preview("Infobox · Team fast fertig") {
        TeamWeekDesignPreview(scenario: .nearlyFinished, streak: 2)
    }
    #Preview("Infobox · Die anderen fast fertig") {
        TeamWeekDesignPreview(scenario: .catchingUp, streak: 3)
    }
    #Preview("Infobox · Team hinterher") { TeamWeekDesignPreview(scenario: .behind, streak: 4) }
    #Preview("Infobox · Du bist auf Kurs") {
        TeamWeekDesignPreview(scenario: .personallyOnTrack, streak: 3)
    }
    #Preview("Infobox · Team auf Kurs") { TeamWeekDesignPreview(scenario: .teamOnTrack, streak: 5) }

    #Preview("Streak 0 · Eisflocke") { TeamWeekDesignPreview(streak: 0, card: 1) }
    #Preview("Streak 1 · Erstes Feuer") { TeamWeekDesignPreview(streak: 1, card: 1) }
    #Preview("Streak 2 · Kleiner Dark Cut") { TeamWeekDesignPreview(streak: 2, card: 1) }
    #Preview("Streak 3 · Layered Flame und Lichtschein") {
        TeamWeekDesignPreview(streak: 3, card: 1)
    }
    #Preview("Streak 4 · Dunkle Wochenbox") { TeamWeekDesignPreview(streak: 4, card: 1) }
    #Preview("Streak 5 · Voller Dark Cut") { TeamWeekDesignPreview(streak: 5, card: 1) }

    #Preview("Streak-Karte · Flammen-Trophäe") { TeamWeekDesignPreview(streak: 3, card: 1) }
    #Preview("Streak-Karte · Level-Up") { TeamWeekDesignPreview(streak: 3, card: 2) }
    #Preview("Streak-Karte · Kette") { TeamWeekDesignPreview(streak: 3, card: 3) }
    #Preview("Streak-Karte · Meilenstein") { TeamWeekDesignPreview(streak: 3, card: 4) }

#endif

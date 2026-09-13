//
//  TeamView.swift
//  identeam
//
//  Created by Nico Stern on 13.03.26.
//

import SwiftData
import SwiftUI
import Kingfisher

struct TeamWeekView: View {
    let slug: String

    @State private var hasLoadedFreshTeamWeek = false
    @State private var showTeamSettings = false
    @State private var showTeamInfo = false
    @State private var showWeekGridSettings = false

    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage private var showIdentImages: Bool // filled in init()
    
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var teamsVM: TeamsViewModel
    @EnvironmentObject var teamVM: TeamWeekViewModel
    @Environment(\.modelContext) private var ctx
    
    @Namespace private var transitions
    
    let isXcodePreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    
    init(slug: String) {
        self.slug = slug
        _showIdentImages = AppStorage(
            wrappedValue: false,
            "week.\(slug).weekgrid.showIdentImages"
        )
    }
    
    @Query private var users: [User]
    private func getUser(userID: String) -> User? {
        users.first { $0.userID == userID }
    }

    @Query private var teams: [Team]
    private var team: Team? {
        teams.first(where: { $0.slug == slug })
    }
    
    @Query private var teamWeeks: [TeamWeek]
    private var teamWeek: TeamWeek? {
        teamWeeks.first(where: { $0.slug == slug })
    }
    
    private var ownMember: TeamMember? {
        teamWeek?.members.first(where: { $0.user.username == username })
    }
    
    private func sortedMembers(for week: TeamWeek) -> [TeamMember] {
        week.members.sorted { lhs, rhs in
            lhs.user.username.lowercased() < rhs.user.username.lowercased()
        }
    }

    private func formattedDateStringShort(for date: Date) -> String {
        date.formatted(
            .dateTime
                .day(.twoDigits)
                .month(.twoDigits)
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }
    
    private let teamGridColumns = Array(
        repeating: GridItem(
            .flexible(minimum: 0),
            spacing: 0
        ),
        count: 8
    )
    
    private func cell<Content: View>(
        isHeader: Bool = false,
        isToday: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .font(isHeader && isToday ? .headline : .body)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                if isHeader {
                    if isToday {
                        Circle().fill(Color("AccentColor").opacity(0.12))
                            .scaleEffect(0.8)
                    } else {
                        Circle().fill(Color.secondary.opacity(0.12))
                            .scaleEffect(0.8)
                    }
                }
            }
            .padding(2)
    }

    @ViewBuilder
    private func dayCell(_ day: MemberDay<Ident>, member: TeamMember) -> some View {
        cell {
            if let ident = day.ident {
                Button {
                    teamVM.selectedIdent = ident
                } label: {
                    VStack(spacing: 4) {
                        identImage(ident: ident, member: member)
                            .frame(height: 55)
                    }
                }
                .buttonStyle(.plain)
            } else if day.isTargetDay {
                Image(systemName: "calendar.badge.clock")
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Nothing planned")
            }
        }
    }

    var body: some View {
        Group { // .refreshable doesn't work on plain View
            if let team {
                List {
                    if hasLoadedFreshTeamWeek, let teamWeek {
                        let members = sortedMembers(for: teamWeek)
                        let dates = TeamWeekGridCalendar.dates(containing: Date())

                        // WeekGrid
                        Section {
                            // lazy grid auto wrangles in rows
                            LazyVGrid(columns: teamGridColumns, spacing: 0) {
                                // header
                                Group {
                                    cell() {
                                        Text("")
                                    }
                                    ForEach(dates, id: \.self) { date in
                                        cell(
                                            isHeader: true,
                                            isToday: Calendar.current.isDateInToday(date)
                                        ) {
                                            Text(ReminderSchedulePlanner.weekdayString(date))
                                        }
                                    }
                                }
                                .padding(.bottom, 10)
                                
                                // row per member
                                ForEach(members, id: \.id) { member in
                                    cell() {
                                        VStack(spacing: 2) {
                                            avatar(image: member.user.avatar)
                                                .padding(1)
                                            Text("\(member.idents.count) / \(member.targetDays.count)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(5)
                                        .frame(maxWidth: .infinity, minHeight: 60)
                                        .clipShape( // Squircle by .continuous
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        )
                                        .background {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(.secondary.opacity(0.12))
                                        }
                                    }
                                    ForEach(dates, id: \.self) { date in
                                        dayCell(
                                            MemberDay(
                                                date: date,
                                                idents: member.idents,
                                                time: \.time,
                                                targetDays: member.targetDays
                                            ),
                                            member: member
                                        )
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text("Current Week")
                                Button {
                                    showWeekGridSettings = true
                                } label: {
                                    Image(systemName: "gearshape")
                                }
                            }
                        } footer: {
                            Text("So far, your team collected \(teamWeek.identSum) / \(teamWeek.targetSum) Idents this week")
                        }
                    } else {
                        Section("TeamWeek") {
                            Text("No Info...").opacity(0.25)
                        }
                    }
                    
                    Section("Actions") {
                        Button() {
                            Task {
                                await teamVM.tryRemindingTeam(slug: team.slug, vm: vm)
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
                    
                    Section("Chat") {
                        Text("Coming soon :)")
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                    .navigationTitle(team.name)
                }
                .refreshable {
                    if await teamsVM.reloadTeamWeek(
                        slug: team.slug,
                        vm: vm,
                        ctx: ctx
                    ) != nil {
                        hasLoadedFreshTeamWeek = true
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showTeamSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .matchedTransitionSource(id: "settings-button", in: transitions)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showTeamInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .matchedTransitionSource(id: "info-button", in: transitions)
                    }
                }
                .sheet(isPresented: $teamVM.showSettingTarget) {
                    NavigationStack {
                        TargetPicker(
                            slug: team.slug
                        ) { didChange in
                            teamVM.showSettingTarget = false
                            if didChange {
                                Task {
                                    if await teamsVM.reloadTeamWeek(
                                        slug: team.slug,
                                        vm: vm,
                                        ctx: ctx
                                    ) != nil {
                                        hasLoadedFreshTeamWeek = true
                                    }
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showTeamSettings) {
                    NavigationStack {
                        TeamSettingsView(
                            slug: team.slug,
                            teamName: team.name,
                            userID: userID
                        )
                    }
                    .navigationTransition(
                        .zoom(sourceID: "settings-button", in: transitions)
                    )
                }
                .sheet(isPresented: $showTeamInfo) {
                    NavigationStack {
                        List {
                            TextLabeled("Slug", team.slug)
                            TextLabeled("Details", team.details)
                        }
                        .navigationTitle(team.name)
                    }
                    .navigationTransition(
                        .zoom(sourceID: "info-button", in: transitions)
                    )
                }
                .sheet(isPresented: $showWeekGridSettings) {
                    NavigationStack {
                        List {
                            Section {
                                Toggle("Idents show images", isOn: $showIdentImages)
                            } footer: {
                                Text("Controls wether ident are filled with user's image or just a color.")
                            }
                        }
                        .padding()
                        .navigationTitle("Grid Settings")
                    }
                    .presentationDetents([.medium])
                }
                .sheet(
                    item: $teamVM.selectedIdent,
                    onDismiss: {
                        teamVM.commentInput = ""
                        teamVM.commentError = ""
                    }
                ) { ident in
                    NavigationStack {
                        // TODO outsource
                        if let member = teamWeek?.members.first(where: { member in
                            member.idents.contains(where: { $0.id == ident.id })
                        }) {
                            List {
                                Section {
                                    HStack {
                                        Spacer()
                                        identImage(ident: ident, member: member, forceShowImage: true)
                                            .modifier(Floating3DEffect(
                                                isActive: true,
                                                animationFactor: 1.2,
                                                showShadow: true
                                            ))
                                            .frame(height: 300)
                                        Spacer()
                                    }
                                    VStack(alignment: .leading) {
                                        Text(formattedDateStringShort(for: ident.time))
                                            .font(.caption)
                                            .opacity(0.5)
                                        
                                        Text(member.user.nickname).bold() + Text("  \(ident.userText)")
                                    }
                                }
                                
                                // Comments
                                if !ident.comments.isEmpty { // otherwise VStack empty list entry
                                    ForEach(ident.comments.sorted(by: {
                                        $0.time < $1.time
                                    })) { comment in
                                        VStack(alignment: .leading) {
                                            Text(formattedDateStringShort(for: comment.time))
                                                .font(.caption)
                                                .opacity(0.5)
                                            
                                            Text(comment.user.nickname).bold() + Text("  \(comment.text)")
                                        }
                                        .contextMenu {
                                            // copy
                                            Button {
                                                UIPasteboard.general.string = comment.text
                                            } label: {
                                                Label("Copy", systemImage: "doc.on.doc")
                                            }
                                            
                                            // [own comment] delete
                                            if comment.user.userID == userID {
                                                Button(role: .destructive) {
                                                    Task {
                                                        await teamVM.tryDeletingComment(
                                                            commentID: comment.id,
                                                            slug: team.slug,
                                                            vm: vm,
                                                            ctx: ctx,
                                                            teamsVM: teamsVM
                                                        )
                                                    }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Comment... prompt
                                VStack {
                                    HStack {
                                        TextField("Comment...", text: $teamVM.commentInput)
                                        Button("Comment") {
                                            Task {
                                                await teamVM.tryCommenting(slug: team.slug, vm: vm, ctx: ctx, teamsVM: teamsVM)
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .glassEffect(.regular.interactive())
                                    }
                                    
                                    if !teamVM.commentError.isEmpty {
                                        Text(teamVM.commentError)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "Failed to load Ident",
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                    }
                    .presentationDetents([.large])
                }
            } else {
                ContentUnavailableView(
                    "Team not found",
                    systemImage: "person.2.slash"
                )
            }
        }
        .task {
            if !isXcodePreview {
                if let team {
                    if await teamsVM.reloadTeamWeek(
                        slug: team.slug,
                        vm: vm,
                        ctx: ctx
                    ) != nil {
                        hasLoadedFreshTeamWeek = true
                    }
                }
            } else {
                hasLoadedFreshTeamWeek = true
            }
        }
    }
    
    func getCachedImage(for item: S3Item) async -> UIImage? {
        await withCheckedContinuation { continuation in
            ImageCache.default.retrieveImage(
                forKey: item.key
            ) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value.image)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func getUserColor(userID: String) async -> Color {
        guard
            let avatarItem = getUser(userID: userID)?.avatar,
            let avatar = await getCachedImage(for: avatarItem)
        else {
            return .accent
        }

        return Color(
            uiColor: avatar.averageColor?.adjustedForUI() ?? .accent
        )
    }
    
    @ViewBuilder
    private func identImage(
        ident: Ident,
        member: TeamMember,
        forceShowImage: Bool = false
    ) -> some View {
        if showIdentImages || forceShowImage {
            let resource = KF.ImageResource(
                downloadURL: ident.image.url,
                cacheKey: ident.image.key
            )
            
            KFImage(source: .network(resource))
                .placeholder {
                    ProgressView()
                }
                .resizable()
                .scaledToFit()
                .mask(
                    Image("Flash")
                        .resizable()
                        .scaledToFill()
                )
                // TODO no overlay since
        } else {
            UserColorFlash(
                userID: member.user.userID,
                getUserColor: getUserColor
            )
        }
    }
    
    private struct UserColorFlash: View {
        let userID: String
        let getUserColor: (String) async -> Color
        
        @State private var userColor: Color?
        
        var body: some View {
            Group {
                if let userColor {
                    Image("Flash")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFill()
                        .foregroundStyle(userColor.opacity(0.7))
                } else {
                    ProgressView()
                }
            }
            .task(id: userID) {
                userColor = await getUserColor(userID)
            }
        }
    }
    
    @ViewBuilder
    private func avatar(image: S3Item) -> some View {
        let resource = KF.ImageResource(
            downloadURL: image.url,
            cacheKey: image.key
        )
        
        KFImage(source: .network(resource))
            .placeholder {
                ProgressView()
            }
            .resizable()
            .scaledToFill()
            .clipShape(Circle())
    }
}

private struct TeamView_PreviewContainer: View {
    let container: ModelContainer
    @StateObject private var teamVM: TeamWeekViewModel

    init(openIdent: Bool = false) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        let container = try! ModelContainer(
            for: Team.self,
            TeamWeek.self,
            TeamMember.self,
            User.self,
            Ident.self,
            S3Item.self,
            Comment.self,
            configurations: config
        )

        let team = Team.templateKanten
        let teamWeek = TeamWeek.templateKanten

        container.mainContext.insert(team)
        container.mainContext.insert(teamWeek)

        let teamVM = TeamWeekViewModel()

        if openIdent {
            teamVM.selectedIdent = teamWeek.members
                .flatMap(\.idents)
                .first
        }

        self.container = container
        _teamVM = StateObject(wrappedValue: teamVM)
    }

    var body: some View {
        TeamWeekView(slug: "die-kanten")
            .environmentObject(AppViewModel())
            .environmentObject(TeamsViewModel())
            .environmentObject(teamVM)
            .modelContainer(container)
    }
}

#Preview("Default") {
    TeamView_PreviewContainer()
}

#Preview("Ident Open") {
    TeamView_PreviewContainer(openIdent: true)
}

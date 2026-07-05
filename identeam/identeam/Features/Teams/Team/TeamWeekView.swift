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
    
    @AppStorage("userID") private var userID: String = ""
    @AppStorage("username") private var username: String = ""
    
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var teamsVM: TeamsViewModel
    @EnvironmentObject var teamVM: TeamWeekViewModel
    @Environment(\.modelContext) private var ctx
    
    let isXcodePreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    @Query private var teams: [Team]
    private var team: Team? {
        teams.first(where: { $0.slug == slug })
    }
    
    @Query private var teamWeeks: [TeamWeek]
    private var teamWeek: TeamWeek? {
        teamWeeks.first(where: { $0.slug == slug })
    }
    
    private var targetSet: Bool {
        guard let teamWeek else { return false }
        return teamWeek.members.contains { member in
            member.user.username == username && member.targetCount > 0
        }
    }
    
    private func sortedMembers(for week: TeamWeek) -> [TeamMember] {
        week.members.sorted { lhs, rhs in
            lhs.user.username.lowercased() < rhs.user.username.lowercased()
        }
    }

    private func sortedIdents(for member: TeamMember) -> [Ident] {
        member.idents.sorted { a, b in
            a.time > b.time
        }
    }

    private func formattedDateString(for date: Date) -> String {
        date.formatted(
            .dateTime
                .weekday(.abbreviated)
                .day()
                .month(.wide)
                .hour()
                .minute()
        )
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

    var body: some View {
        Group {
            if let team {
                List {
                    Section("Info") {
                        TextLabeled("Slug", team.slug)
                        TextLabeled("Details", team.details)
                    }
                    
                    if let teamWeek {
                        Section("Members ⋅ \(teamWeek.identSum) / \(teamWeek.targetSum) Idents ") {
                            ForEach(sortedMembers(for: teamWeek), id: \.id) { member in
                                DisclosureGroup {
                                    ForEach(sortedIdents(for: member), id: \.id) { ident in
                                        let dateString = formattedDateString(for: ident.time)
                                        HStack {
                                            identImage(ident: ident)
                                                .frame(height: 75)
                                            TextLabeled(dateString, ident.userText)
                                        }
                                        .onTapGesture {
                                            teamVM.selectedIdent = ident
                                        }
                                    }
                                } label: {
                                    HStack {
                                        avatar(image: member.user.avatar)
                                            .frame(height: 50)
                                        TextLabeled(
                                            "\(member.idents.count) / \(member.targetCount)",
                                            member.user.nickname
                                        )
                                    }
                                }
                            }
                        }
                    } else {
                        Section("TeamWeek") {
                            Text("No Info...").opacity(0.25)
                        }
                    }
                    
                    Section("My Target") {
                        Button() {
                            teamVM.showSettingTarget = true
                        } label: {
                            Text(targetSet ? "Change Target" : "Set Target")
                        }
                    }
                    
                    Section("Debugging") {
                        Button("Notify Team") {
                            Task {
                                do {
                                    try await TeamAPI.shared.NotifyTeam(slug: team.slug)
                                } catch {
                                    vm.showAlert(
                                        "Error notifying team",
                                        error.localizedDescription
                                    )
                                }
                            }
                        }
                    }
                    .navigationTitle(team.name)
                }
                .listStyle(InsetGroupedListStyle())
                .sheet(isPresented: $teamVM.showSettingTarget) {
                    NavigationStack {
                        TargetPicker(
                            slug: team.slug,
                        ) { didChange in
                            teamVM.showSettingTarget = false
                            if didChange {
                                Task {
                                    await teamsVM.reloadTeamWeek(slug: team.slug, vm: vm, ctx: ctx)
                                }
                            }
                        }
                    }
                }
                .sheet(
                    item: $teamVM.selectedIdent,
                    onDismiss: {
                        teamVM.commentInput = ""
                        teamVM.commentError = ""
                    }
                ) { ident in
                    NavigationStack {
                        VStack() {
                            Text(ident.userText)
                                .padding()
                                .bold()
                            
                            identImage(ident: ident)
                                .modifier(Floating3DEffect(isActive: true, animationFactor: 1))
                                .cornerRadius(12)
                            
                            // Comments
                            VStack(alignment: .leading) {
                                ForEach(ident.comments.sorted(by: {
                                    $0.time < $1.time
                                })) { comment in
                                    VStack(alignment: .leading) {
                                        Text(formattedDateStringShort(for: comment.time))
                                            .font(.caption)
                                            .opacity(0.5)
                                        
                                        HStack(spacing: 10) {
                                            Text(comment.user.nickname)
                                                .bold()
                                            Text(comment.text)
                                        }
                                    }
                                    .padding(5)
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = comment.text
                                        } label: {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                        
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
                                
                                TextField("Comment...", text: $teamVM.commentInput)
                                    .padding(5)
                                Text(teamVM.commentError)
                                    .foregroundStyle(.red)
                                
                            }
                            .padding()
                            
                            Button {
                                Task {
                                    await teamVM.tryCommenting(slug: team.slug, vm: vm, ctx: ctx, teamsVM: teamsVM)
                                }
                            } label: {
                                Text("Comment")
                                    .padding(5)
                            }
                            .buttonStyle(.borderedProminent)
                            .glassEffect(.regular.interactive())
                        }
                        .padding()
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
        .refreshable {
            if let team {
                await teamsVM.reloadTeamWeek(slug: team.slug, vm: vm, ctx: ctx)
            }
        }
        .task {
            if !isXcodePreview {
                if let team {
                    await teamsVM.reloadTeamWeek(slug: team.slug, vm: vm, ctx: ctx)
                }
            }
        }
    }
    
    @ViewBuilder
    private func identImage(ident: Ident) -> some View {
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
            .scaledToFit()
            .mask(Circle())
    }
}

private struct TeamView_PreviewContainer: View {
    let container: ModelContainer

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        self.container = try! ModelContainer(
            for: Team.self,
            TeamWeek.self,
            TeamMember.self,
            User.self,
            Ident.self,
            S3Item.self,
            Comment.self,
            configurations: config
        )

        // Insert mock data into the in-memory context
        container.mainContext.insert(Team.templateKanten)
        container.mainContext.insert(TeamWeek.templateKanten)
    }

    var body: some View {
        TeamWeekView(slug: "die-kanten")
            .environmentObject(AppViewModel())
            .environmentObject(TeamsViewModel())
            .environmentObject(TeamWeekViewModel())
            .modelContainer(container)
    }
}

#Preview {
    TeamView_PreviewContainer()
}

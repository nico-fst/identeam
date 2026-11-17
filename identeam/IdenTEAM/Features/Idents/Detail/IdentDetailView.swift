import SwiftData
import SwiftUI

struct IdentDetailView: View {
    let ident: Ident
    let member: TeamMember
    let slug: String
    var referenceDate = Date()
    @State private var selectedProfileUser: User?

    @AppStorage("userID") private var userID = ""
    @EnvironmentObject private var vm: AppVM
    @EnvironmentObject private var teamsVM: TeamsVM
    @EnvironmentObject private var teamVM: TeamWeekVM
    @Environment(\.modelContext) private var ctx

    var body: some View {
        List {
            Group {
                Section {
                    HStack {
                        Spacer()
                        IdentImageView(image: RemoteImageReference(item: ident.image))
                            .modifier(
                                Floating3DEffect(
                                    isActive: true,
                                    animationFactor: 1.2,
                                    showShadow: true
                                )
                            )
                            .frame(height: 300)
                        Spacer()
                    }
                    VStack(alignment: .leading) {
                        Text(AppCalendar.shortDateAndTime(for: ident.time))
                            .font(.nunito(.caption))
                            .opacity(0.5)

                        message(ident.userText, author: member.user)
                    }
                }

                // Comments
                if !ident.comments.isEmpty {  // otherwise VStack empty list entry
                    ForEach(
                        ident.comments.sorted(by: {
                            $0.time < $1.time
                        })
                    ) { comment in
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                selectedProfileUser = comment.user
                            } label: {
                                UserAvatarView(
                                    image: RemoteImageReference(item: comment.user.avatar)
                                )
                                .frame(width: 40, height: 40)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Profil von \(comment.user.nickname)")

                            VStack(alignment: .leading) {
                                Text(AppCalendar.shortDateAndTime(for: comment.time))
                                    .font(.nunito(.caption))
                                    .opacity(0.5)

                                message(comment.text, author: comment.user)
                            }
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
                                            slug: slug,
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
                                await teamVM.tryCommenting(
                                    slug: slug, vm: vm, ctx: ctx, teamsVM: teamsVM)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accent)
                        .foregroundStyle(AppColor.onAccent)
                        .glassEffect(.regular.tint(AppColor.selection).interactive())
                    }

                    if !teamVM.commentError.isEmpty {
                        Text(teamVM.commentError)
                            .foregroundStyle(AppColor.error)
                    }
                }
            }
            .listRowBackground(AppColor.surface)
        }
        .appListColors()
        .sheet(item: $selectedProfileUser) { user in
            NavigationStack {
                TeamMemberProfileView(
                    user: user, slug: slug,
                    month: AppCalendar.startOfMonth(containing: ident.time), viewerID: userID,
                    referenceDate: referenceDate,
                    showsMonth: AppCalendar.startOfWeek(containing: ident.time)
                        <= AppCalendar.startOfWeek(containing: referenceDate))
            }
        }
    }

    private func message(_ text: String, author: User) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Button {
                selectedProfileUser = author
            } label: {
                Text(author.nickname).bold()
            }
            .buttonStyle(.plain)
            Text(text).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

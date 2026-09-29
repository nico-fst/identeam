import SwiftData
import SwiftUI

struct IdentDetailView: View {
    let ident: Ident
    let member: TeamMember
    let slug: String

    @AppStorage("userID") private var userID = ""
    @EnvironmentObject private var vm: AppVM
    @EnvironmentObject private var teamsVM: TeamsVM
    @EnvironmentObject private var teamVM: TeamWeekVM
    @Environment(\.modelContext) private var ctx

    var body: some View {
        List {
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
                        .font(.caption)
                        .opacity(0.5)

                    Text("\(Text(member.user.nickname).bold())  \(ident.userText)")
                }
            }

            // Comments
            if !ident.comments.isEmpty {  // otherwise VStack empty list entry
                ForEach(
                    ident.comments.sorted(by: {
                        $0.time < $1.time
                    })
                ) { comment in
                    VStack(alignment: .leading) {
                        Text(AppCalendar.shortDateAndTime(for: comment.time))
                            .font(.caption)
                            .opacity(0.5)

                        Text("\(Text(comment.user.nickname).bold())  \(comment.text)")
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
                    .glassEffect(.regular.interactive())
                }

                if !teamVM.commentError.isEmpty {
                    Text(teamVM.commentError)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

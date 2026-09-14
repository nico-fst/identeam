import SwiftUI
import SwiftData

struct IdentDetailView: View {
    let ident: Ident
    let member: TeamMember
    let slug: String

    @AppStorage("userID") private var userID = ""
    @EnvironmentObject private var vm: AppViewModel
    @EnvironmentObject private var teamsVM: TeamsViewModel
    @EnvironmentObject private var teamVM: TeamWeekViewModel
    @Environment(\.modelContext) private var ctx

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
        List {
            Section {
                HStack {
                    Spacer()
                    IdentImageView(image: RemoteImageReference(item: ident.image))
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
                            await teamVM.tryCommenting(slug: slug, vm: vm, ctx: ctx, teamsVM: teamsVM)
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

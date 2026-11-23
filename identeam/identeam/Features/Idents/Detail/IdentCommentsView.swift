import SwiftUI

struct IdentCommentsView: View {
    let comments: [Comment]
    let currentUserID: String
    let color: Color
    @Binding var drag: CGFloat
    let onSelectUser: (User) -> Void
    let onDelete: (Int) -> Void
    let onDismiss: () -> Void
    @State private var scrollAtTop = true

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Kommentare").font(.nunito(.headline))
                        Text("\(comments.count)").font(.nunito(.caption).weight(.bold))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(color.opacity(0.13), in: .capsule)
                        Spacer()
                    }
                    if comments.isEmpty {
                        Text("Noch keine Kommentare. Schreib den ersten!")
                            .font(.nunito(.subheadline)).foregroundStyle(AppColor.muted)
                            .padding(.vertical, 24)
                    }
                    ForEach(comments) { comment in
                        IdentCommentRow(
                            user: comment.user, date: comment.time, text: comment.text,
                            onSelectUser: onSelectUser
                        )
                        .id(comment.id)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Kopieren", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = comment.text
                            }
                            if comment.user.userID == currentUserID {
                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    onDelete(comment.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.top, 30).padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: Bool.self) {
                $0.contentOffset.y + $0.contentInsets.top <= 1
            } action: { _, atTop in
                scrollAtTop = atTop
            }
            .onChange(of: comments.count) {
                if let last = comments.last {
                    withAnimation { scroll.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .clipShape(.rect(cornerRadius: 36))
        .foregroundStyle(AppColor.text)
        .glassEffect(.regular.tint(AppColor.background.opacity(0.18)), in: .rect(cornerRadius: 36))
        .overlay {
            RoundedRectangle(cornerRadius: 36).stroke(.white.opacity(0.22), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        .modifier(IdentPanelDrag(offset: $drag, canStart: scrollAtTop, onDismiss: onDismiss))
    }
}

/// A flowing name/message line with quiet metadata below, like a social comment thread.
struct IdentCommentRow: View {
    let user: User
    let date: Date
    let text: String
    let onSelectUser: (User) -> Void

    private var message: AttributedString {
        var name = AttributedString(user.nickname)
        name.font = .nunito(.subheadline).weight(.bold)
        name.link = URL(string: "identeam://comment-author")
        return name + AttributedString("  \(text)")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                onSelectUser(user)
            } label: {
                UserAvatarView(image: RemoteImageReference(item: user.avatar))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 6) {
                Text(message).font(.nunito(.subheadline)).tint(AppColor.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(
                        \.openURL,
                        OpenURLAction { _ in
                            onSelectUser(user)
                            return .handled
                        })
                Text(AppCalendar.shortDateAndTime(for: date))
                    .font(.nunito(.caption2)).foregroundStyle(AppColor.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppColor.text)
    }
}

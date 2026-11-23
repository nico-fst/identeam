import SwiftUI

/// An independent input tray: only this surface follows the keyboard.
struct IdentCommentComposer: View {
    @Binding var text: String
    let error: String
    let user: User?
    let color: Color
    let isSending: Bool
    let canSend: Bool
    let focus: FocusState<Bool>.Binding
    let onSend: () -> Void
    @State private var inputHeight: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !error.isEmpty {
                Text(error).font(.nunito(.caption)).foregroundStyle(AppColor.error)
            }
            HStack(alignment: .center, spacing: 10) {
                Group {
                    if let user {
                        UserAvatarView(image: RemoteImageReference(item: user.avatar))
                    } else {
                        Image(systemName: "person.fill")
                            .background(color.opacity(0.12), in: .circle)
                    }
                }
                .frame(width: inputHeight, height: inputHeight)

                HStack(alignment: .center, spacing: 8) {
                    TextField("Kommentar …", text: $text, axis: .vertical)
                        .font(.custom("Nunito-SemiBold", size: 16, relativeTo: .body))
                        .lineLimit(1...4)
                        .frame(minHeight: 36, alignment: .center)
                        .focused(focus)
                        .disabled(isSending)
                    Button(action: onSend) {
                        Group {
                            if isSending {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold))
                            }
                        }
                        .frame(width: 34, height: 34)
                        .foregroundStyle(.white)
                        .background(color, in: .circle)
                    }
                    .disabled(!canSend)
                    .opacity(canSend || isSending ? 1 : 0.4)
                }
                .padding(.leading, 16).padding(6)
                .background(color.opacity(0.09), in: .rect(cornerRadius: 24))
                .onGeometryChange(for: CGFloat.self) {  // ensures avatar beging as tall as input line
                    $0.size.height
                } action: {
                    inputHeight = $0
                }
            }
        }
        .foregroundStyle(AppColor.text)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .glassEffect(.regular.tint(AppColor.background.opacity(0.18)), in: .rect(cornerRadius: 36))
    }
}

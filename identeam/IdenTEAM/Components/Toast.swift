import SwiftUI

struct ToastContainer<Content: View>: View {
    @Binding var toastMessage: String?
    let content: Content

    init(toastMessage: Binding<String?>, @ViewBuilder content: () -> Content) {
        self._toastMessage = toastMessage
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            content

            if let message = toastMessage {
                ToastView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                toastMessage = nil
                            }
                        }
                    }
                    .padding(.top, 10)  // distance to notch
            }
        }
        .animation(.spring(), value: toastMessage)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Color("AccentColor"))
        )
        .padding(.horizontal, 16)
        .shadow(radius: 4)
    }
}

#Preview {
    @Previewable @State var toastMessage: String? = "ToastView Message"

    ToastContainer(toastMessage: $toastMessage) {
        ContentView()
            .environmentObject(AppViewModel())
            .environmentObject(AuthViewModel())
            .environmentObject(TeamsViewModel())
    }
}

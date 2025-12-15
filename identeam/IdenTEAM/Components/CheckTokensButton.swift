import SwiftUI

struct CheckTokensButton: View {
    // TODO switch to Keychain storage
    @AppStorage("sessionToken") private var sessionToken: String = ""

    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Button("Check Tokens") {
            Task {
                do {
                    // if isValid
                    let _ = try await AuthService.shared
                        .letBackendValidateSessionToken()
                    authVM.alertMessage = "Token is valid"
                } catch {
                    authVM.alertMessage = error.localizedDescription
                }

                authVM.showAlert = true
            }
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
        .alert(isPresented: $authVM.showAlert) {
            Alert(
                title: Text("Auth Response"),
                message: Text(authVM.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

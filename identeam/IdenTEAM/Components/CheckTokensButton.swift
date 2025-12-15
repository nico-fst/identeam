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
                    if try await AuthService.shared
                        .letBackendValidateSessionToken()
                    {
                        authVM.showAlert = true
                        authVM.alertMessage = "Token is valid"
                    } else {
                        authVM.showAlert = true
                        authVM.alertMessage = "Token is not valid"
                    }
                } catch {
                    authVM.showAlert = true
                    authVM.alertMessage = error.localizedDescription
                }
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

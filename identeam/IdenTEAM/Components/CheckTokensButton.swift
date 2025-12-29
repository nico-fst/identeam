import SwiftUI

struct CheckTokensButton: View {
    // TODO switch to Keychain storage
    @AppStorage("sessionToken") private var sessionToken: String = ""

    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        Button("Check Tokens") {
            Task {
                do {
                    // if isValid
                    let _ = try await AuthService.shared
                        .letBackendValidateSessionToken()
                    vm.toastMessage = "Token is valid :)"
                    vm.showAlert("Token Check", "Token is valid :)")
                } catch {
                    vm.showAlert("Error Checking Token", error.localizedDescription)
                }
            }
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}

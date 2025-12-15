import AuthenticationServices
import SwiftUI

struct SignInWithAppleButtonView: View {
    @AppStorage("sessionToken") private var sessionToken: String?
    @AppStorage("deviceToken") private var deviceToken: String?

    @AppStorage("currentUserID") private var currentUserID: String?
    @AppStorage("currentUserEmail") private var currentUserEmail: String?
    @AppStorage("currentUserFullName") private var currentUserFullName: String?

    @EnvironmentObject var authVM: AuthViewModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                switch result {
                case .success(let authResults):
                    handle(authResults)
                case .failure(let error):
                    authVM.showAlert = true
                    authVM.alertMessage = error.localizedDescription
                }
            }
        )
        .signInWithAppleButtonStyle(
            colorScheme == .dark ? .white : .black
        )
        .frame(height: 45)
        .frame(maxWidth: 375)
        .cornerRadius(.infinity)
        .padding(.horizontal)
    }

    private func handle(_ authResults: ASAuthorization) {
        if let appleIDCredential = authResults.credential
            as? ASAuthorizationAppleIDCredential
        {
            guard
                let identityTokenData = appleIDCredential.identityToken,
                let identityToken = String(
                    data: identityTokenData,
                    encoding: .utf8
                ),
                let authorizationCodeData = appleIDCredential.authorizationCode,
                let authorizationCode = String(
                    data: authorizationCodeData,
                    encoding: .utf8
                )
            else {
                print("Failed to retrieve tokens")
                return
            }

            let user = User(
                userID: appleIDCredential.user,
                email: "",  // backend looks manually up after validating JWT against Apple server
                fullName: PersonNameComponentsFormatter().string(
                    from: appleIDCredential.fullName ?? PersonNameComponents()
                )
            )

            Task {
                do {
                    let response = try await AuthService.shared
                        .sendAuthFlowToBackend(
                            identityToken: identityToken,
                            authorizationCode: authorizationCode,
                            user: user
                        )
                    self.sessionToken = response.sessionToken
                    self.currentUserID = response.user.userID
                    self.currentUserEmail = response.user.email
                    self.currentUserFullName = response.user.fullName

                    try await TokenService.shared.sendDeviceTokenToBackend()
                    await authVM.tryLogin()
                } catch {
                    authVM.showAlert = true
                    authVM.alertMessage =
                        "ERROR sending device token to backend: "
                        + error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    SignInWithAppleButtonView()
        .environmentObject(AuthViewModel())
}

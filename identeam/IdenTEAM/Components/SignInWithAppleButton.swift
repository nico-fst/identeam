import AuthenticationServices
import SwiftUI

struct SignInWithAppleButtonComponent: View {
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
                ),
                username: ""
            )

            Task {
                let response = try await AuthService.shared
                    .sendAuthFlowToBackend(
                        identityToken: identityToken,
                        authorizationCode: authorizationCode,
                        user: user
                    )

                // not tryLogin() since in async and variables not stable yet
                authVM.completeLogin(
                    sessionToken: response.sessionToken,
                    userID: response.user.userID,
                    email: response.user.email,
                    fullName: response.user.fullName,
                    username: response.user.username,
                    created: response.created
                )

                try await TokenService.shared.sendDeviceTokenToBackend()
            }
        }
    }
}

#Preview {
    SignInWithAppleButtonComponent()
        .environmentObject(AuthViewModel())
}

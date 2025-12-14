import AuthenticationServices
import SwiftUI

struct SignInWithAppleButtonView: View {
    @AppStorage("sessionToken") private var sessionToken: String = ""
    @AppStorage("deviceToken") private var deviceToken: String = ""

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
                    print("Authorization failed: \(error.localizedDescription)")
                }
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 45)
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

            sendToBackend(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                userID: appleIDCredential.user,
                fullName: appleIDCredential.fullName
            )
        }
    }

    private func sendToBackend(
        identityToken: String,
        authorizationCode: String,
        userID: String,
        fullName: PersonNameComponents?
    ) {
        guard
            let url = URL(
                string:
                    "https://unconvolute-effectively-leeanna.ngrok-free.dev/auth/apple/native/callback"
            )
        else { return }

        var payload: [String: Any] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode,
            "userID": userID,
        ]

        if let fullName = fullName {
            let formatter = PersonNameComponentsFormatter()
            payload["fullName"] = formatter.string(from: fullName)
        }

        guard
            let jsonData = try? JSONSerialization.data(withJSONObject: payload)
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Network error:", error)
                return
            }

            guard let data = data else { return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                    let dataDict = json["data"] as? [String: Any]
                {
                    // Speichere die Tokens persistent mit @AppStorage
                    if let sToken = dataDict["sessionToken"] as? String {
                        DispatchQueue.main.async { sessionToken = sToken }  // DispatchQueue since UI-Updates only on main thread
                        print("Received sessionToken: \(sToken)")
                        print("Sending \(sessionToken) and \(deviceToken) -> Backend")
                        sendDeviceTokenToBackend(sessionToken: sessionToken, deviceToken: deviceToken)
                    }
                }
            } catch {
                print("Failed to parse JSON:", error)
            }
        }.resume()
    }

    private func sendDeviceTokenToBackend(sessionToken: String, deviceToken: String) {
        guard
            let url = URL(
                string:
                    "https://unconvolute-effectively-leeanna.ngrok-free.dev/auth/update_device_token"
            )
        else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(
            "Bearer \(sessionToken)",
            forHTTPHeaderField: "Authorization"
        )

        let body: [String: String] = [
            "newToken": deviceToken,
            "platform": "ios",
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)  // try? returns nil on error

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error {
                print("Network error:", error)
                return
            }

            guard let data = data else { return }

            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw response:", rawResponse)
            } else {
                print("Raw response could not be decoded as UTF-8")
            }
        }.resume()
    }
}

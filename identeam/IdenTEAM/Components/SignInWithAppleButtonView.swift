//
//  SignInWithAppleButtonView.swift
//  identeam
//
//  Created by Nico Stern on 12.12.25.
//

import AuthenticationServices
import SwiftUI

struct SignInWithAppleButtonView: View {
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
            let userIdentifier = appleIDCredential.user
            let identityTokenData = appleIDCredential.identityToken
            let authorizationCodeData = appleIDCredential.authorizationCode
            let fullName = appleIDCredential.fullName

            // Convert tokens to String
            guard
                let tokenData = identityTokenData,
                let tokenString = String(data: tokenData, encoding: .utf8)
            else {
                print("Failed to retrieve identity token")
                return
            }

            guard
                let codeData = authorizationCodeData,
                let codeString = String(data: codeData, encoding: .utf8)
            else {
                print("Failed to retrieve authorization code")
                return
            }

            sendToBackend(
                identityToken: tokenString,
                authorizationCode: codeString,
                userID: userIdentifier,
                fullName: fullName
            )
        }
    }

    func sendToBackend(
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
        else {
            print("Invalid URL")
            return
        }

        // Convert PersonNameComponents? to a display string if available
        var fullNameString: String? = nil
        if let fullName = fullName {
            let formatter = PersonNameComponentsFormatter()
            fullNameString = formatter.string(from: fullName)
        }

        var payload: [String: Any] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode,
            "userID": userID,
        ]
        if let fullNameString = fullNameString {
            payload["fullName"] = fullNameString
        }

        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(
                withJSONObject: payload,
                options: []
            )
        } catch {
            print("Failed to serialize JSON: \(error)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            print("---- URLSession Debug ----")
            print("Error: \(String(describing: error))")
            print("Response: \(String(describing: response))")
            print("Data (raw): \(String(describing: data))")

            if let data = data, let text = String(data: data, encoding: .utf8) {
                print("Backend response:", text)
            }
        }.resume()
    }
}

#Preview {
    SignInWithAppleButtonView()
}

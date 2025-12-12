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
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private func handle(_ authResults: ASAuthorization) {
        if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let identityToken = appleIDCredential.identityToken

            // Convert identity token to String
            if let tokenData = identityToken,
               let tokenString = String(data: tokenData, encoding: .utf8) {
                sendToBackend(token: tokenString, userID: userIdentifier)
            } else {
                print("Failed to retrieve identity token")
            }
        }
    }

    private func sendToBackend(token: String, userID: String) {
        guard let url = URL(string: "https://unconvolute-effectively-leeanna.ngrok-free.dev/auth/apple/native") else {
            print("Invalid backend URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "identityToken": token,
            "userID": userID,
        ]

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            print("Failed to encode request body: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Backend error: \(error)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Backend status: \(httpResponse.statusCode)")
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Backend response: \(responseString)")
            } else {
                print("Sign in with Apple successful")
            }
        }.resume()
    }
}

#Preview {
    SignInWithAppleButtonView()
}

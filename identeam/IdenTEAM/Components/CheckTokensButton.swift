import SwiftUI

struct CheckTokensButton: View {
    // TODO switch to Keychain storage
    @AppStorage("sessionToken") private var sessionToken: String = ""

    @State private var alertMessage: String = ""
    @State private var showAlert = false

    var body: some View {
        Button("Check Tokens") {
            checkTokens()
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Token Check"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func checkTokens() {
        guard
            let url = URL(
                string:
                    "https://unconvolute-effectively-leeanna.ngrok-free.dev/auth/apple/check_session"
            )
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.setValue(
            "Bearer \(sessionToken)",
            forHTTPHeaderField: "Authorization"
        )

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage =
                        "Network error: \(error.localizedDescription)"
                    showAlert = true
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    alertMessage = "Invalid response"
                    showAlert = true
                }
                return
            }

            DispatchQueue.main.async {
                switch httpResponse.statusCode {
                case 204:
                    alertMessage = "Session Token valid"
                case 401:
                    alertMessage = "Session Token invalid or expired"
                default:
                    alertMessage =
                        "Unexpected status: \(httpResponse.statusCode)"
                }
                showAlert = true
            }
        }.resume()
    }
}

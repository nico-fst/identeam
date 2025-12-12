import SwiftUI

struct CheckTokensButton: View {
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

        let payload: [String: Any] = [
            "sessionToken": sessionToken
        ]

        guard
            let jsonData = try? JSONSerialization.data(withJSONObject: payload)
        else { return }
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                alertMessage = "Network error: \(error.localizedDescription)"
                showAlert = true
                return
            }

            guard let data = data else {
                alertMessage = "No response data"
                showAlert = true
                return
            }
            print("RAW RESPONSE:", String(data: data, encoding: .utf8) ?? "nil")

            do {
                let json =
                    try JSONSerialization.jsonObject(with: data)
                    as? [String: Any]
                if let dataDict = json?["data"] as? [String: Any],
                   let sessionValid = dataDict["sessionValid"] as? Bool
                {
                    alertMessage = """
                        Session Token valid: \(sessionValid)
                        """
                } else {
                    alertMessage = "Unexpected response format"
                }
            } catch {
                alertMessage = "Failed to parse JSON: \(error)"
            }

            DispatchQueue.main.async {
                showAlert = true
            }
        }.resume()
    }
}

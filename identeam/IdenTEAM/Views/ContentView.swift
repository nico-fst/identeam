//
//  ContentView.swift
//  identeam
//
//  Created by Nico Stern on 23.11.25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel

    @AppStorage("userID") private var userID: String?
    @AppStorage("email") private var email: String?
    @AppStorage("fullName") private var fullName: String?
    @AppStorage("username") private var username: String?

    @AppStorage("deviceToken") private var deviceToken: String?
    @AppStorage("sessionToken") private var sessionToken: String?

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                Text("Hello \(fullName ?? "no username") 👋🏼")

                Text("BaseURL: \(AppConfig.apiBaseURL)")
                Text("DeviceToken: \(deviceToken ?? "no device token")")
                Text("SessionToken: \(sessionToken ?? "no session token")")

                Spacer()

                Text(authVM.authState.rawValue).bold()
                Text(userID ?? "no user id")
                Text(email ?? "no user email")
                Text(fullName ?? "no user full name")
                Text(username ?? "no user username")

                Spacer()

                switch authVM.authState {
                case .unknown:
                    ProgressView("Checking Session...")
                case .unauthenticated:
                    SignInWithAppleButtonComponent()
                case .authenticated:
                    Button("Logout") {
                        authVM.logout()
                    }
                }
                CheckTokensButton()

                Spacer()
            }
            .task {
                await authVM.tryLogin()
            }
        }
        .sheet(isPresented: $authVM.showLoginSheet) {
            NavigationStack {
                VStack {
                    if !authVM.showEnterUserDetails {
                        // step 1
                        SignInWithAppleButtonComponent()
                    } else {
                        // step 2 (only after signing up)
                        VStack {
                            List {
                                TextField(
                                    "Your Name",
                                    text: $authVM.fullnameInput
                                )
                                TextField(
                                    "Username",
                                    text: $authVM.usernameInput
                                )
                            }
                            
                            Text(authVM.signupError ?? "")
                                .foregroundColor(.red)

                            Button("Sign Up") {
                                Task { await authVM.tryChangeUserDetails() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    }
                }
                .navigationTitle("Login with Apple")
            }
            .interactiveDismissDisabled()
            .presentationDetents([.medium])
        }
        .alert(isPresented: $authVM.showAlert) {
            Alert(
                title: Text("Auth Response"),
                message: Text(authVM.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}

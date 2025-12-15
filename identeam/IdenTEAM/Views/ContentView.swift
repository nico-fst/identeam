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

    @AppStorage("currentUserID") private var currentUserID: String?
    @AppStorage("currentUserEmail") private var currentUserEmail: String?
    @AppStorage("currentUserFullName") private var currentUserFullName: String?
    @AppStorage("deviceToken") private var deviceToken: String?
    @AppStorage("sessionToken") private var sessionToken: String?

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                Text("BaseURL: \(AppConfig.apiBaseURL)")
                Text("DeviceToken: \(deviceToken ?? "no device token")")
                Text("SessionToken: \(sessionToken ?? "no session token")")

                Spacer()

                Text(authVM.authState.rawValue).bold()
                Text(currentUserID ?? "no user id")
                Text(currentUserEmail ?? "no user email")
                Text(currentUserFullName ?? "no user full name")

                Spacer()

                switch authVM.authState {
                case .unknown:
                    ProgressView("Checking Session...")
                case .unauthenticated:
                    SignInWithAppleButtonView()
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
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}

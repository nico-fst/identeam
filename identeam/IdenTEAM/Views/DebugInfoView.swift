//
//  DebugInfoView.swift
//  identeam
//
//  Created by Nico Stern on 28.12.25.
//

import SwiftData
import SwiftUI

struct DebugInfoView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext

    @AppStorage("userID") private var userID: String?
    @AppStorage("email") private var email: String?
    @AppStorage("fullName") private var fullName: String?
    @AppStorage("username") private var username: String?
    @AppStorage("deviceToken") private var deviceToken: String?
    @AppStorage("sessionToken") private var sessionToken: String?

    var body: some View {
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
}

#Preview {
    DebugInfoView()
        .environmentObject(AuthViewModel())
}

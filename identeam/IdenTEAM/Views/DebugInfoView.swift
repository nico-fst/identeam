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
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext

    @AppStorage("userID") private var userID: String?
    @AppStorage("email") private var email: String?
    @AppStorage("fullName") private var fullName: String?
    @AppStorage("username") private var username: String?
    @AppStorage("deviceToken") private var deviceToken: String?
    @AppStorage("sessionToken") private var sessionToken: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Device Config") {
                    TextLabeled("Base URL", "\(AppConfig.apiBaseURL)")
                    TextLabeled("Device Token", deviceToken ?? "")
                }
                
                Section("Authentication ⋅ \(authVM.authState.rawValue)") {
                    TextLabeled("Session Token", sessionToken ?? "")
                    TextLabeled("UserID", userID ?? "")
                    TextLabeled("Email", email ?? "")
                    TextLabeled("Full Name", fullName ?? "")
                    TextLabeled("Username", username ?? "")
                }
                
                switch authVM.authState {
                case .unknown:
                    ProgressView("Checking Session...")
                case .unauthenticated:
                    Text("Please restart the app to log in again")
                        .foregroundStyle(.red).bold()
                case .enteringUserDetails:
                    Text("Entering User Details...")
                case .authenticated:
                    CheckTokensButton()
                    Button("Logout") {
                        authVM.logout()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Hello \(fullName ?? "(no username)") 👋🏼")
            .task {
                await authVM.trySiwaLogin(vm: vm)
            }
        }
    }
}

#Preview {
    DebugInfoView()
        .environmentObject(AuthViewModel())
        .environmentObject(AppViewModel())
}

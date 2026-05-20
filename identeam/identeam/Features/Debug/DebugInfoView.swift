//
//  DebugInfoView.swift
//  identeam
//
//  Created by Nico Stern on 28.12.25.
//

import PhotosUI
import SwiftData
import SwiftUI

struct DebugInfoView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var avatarVM: AvatarViewModel
    
    @Environment(\.modelContext) private var ctx

    @AppStorage("userID") private var userID: String?
    @AppStorage("email") private var email: String?
    @AppStorage("fullName") private var fullName: String?
    @AppStorage("username") private var username: String?
    @AppStorage("deviceToken") private var deviceToken: String?
    @AppStorage("sessionToken") private var sessionToken: String?
    
    @Query(filter: #Predicate<S3Item> {
        $0.kindRaw == "avatar"
    }) private var avatars: [S3Item]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    AvatarPicker()
                }
                
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
                        authVM.logout(ctx: ctx)
                    }
                    .foregroundStyle(.red)
                }
            }
            .refreshable {
                Task {
                    try? await avatarVM.refreshAvatarIfNeeded(avatars: avatars, ctx: ctx)
                }
            }
            .onChange(of: userID) {
                Task {
                    try? await avatarVM.refreshAvatarIfNeeded(avatars: avatars, ctx: ctx)
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
        .environmentObject(AvatarViewModel())
}

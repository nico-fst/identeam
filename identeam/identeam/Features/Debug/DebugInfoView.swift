import PhotosUI
import SwiftData
import SwiftUI

struct DebugInfoView: View {
    @EnvironmentObject var authVM: AuthVM
    @EnvironmentObject var vm: AppVM
    @EnvironmentObject var avatarVM: AvatarVM
    @EnvironmentObject var navVM: NavigationVM

    @Environment(\.modelContext) private var ctx

    @AppStorage("userID") private var userID: String?
    @AppStorage("email") private var email: String?
    @AppStorage("nickname") private var nickname: String?
    @AppStorage("username") private var username: String?
    @AppStorage("deviceToken") private var deviceToken: String?
    @AppStorage("sessionToken") private var sessionToken: String?

    @Query(
        filter: #Predicate<S3Item> {
            $0.kindRaw == "ownAvatar"
        }) private var avatars: [S3Item]

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        AvatarPicker()
                    } header: {
                        Text("Profile")
                            .font(.nunito(.headline))
                    }

                    Section {
                        TextLabeled("Base URL", "\(AppConfig.apiBaseURL)")
                        TextLabeled("Device Token", deviceToken ?? "")
                    } header: {
                        Text("Device Config")
                            .font(.nunito(.headline))
                    }

                    Section {
                        TextLabeled("Session Token", sessionToken ?? "")
                        TextLabeled("UserID", userID ?? "")
                        TextLabeled("Email", email ?? "")
                        TextLabeled("Nickname", nickname ?? "")
                        TextLabeled("Username", username ?? "")
                    } header: {
                        Text("Authentication ⋅ \(authVM.authState.rawValue)")
                            .font(.nunito(.headline))
                    }

                    switch authVM.authState {
                    case .unknown:
                        ProgressView("Checking Session...")
                    case .unauthenticated:
                        Text("Please restart the app to log in again")
                            .foregroundStyle(IgniteColor.error).bold()
                    case .enteringUserDetails:
                        Text("Entering User Details...")
                    case .authenticated:
                        CheckTokensButton()
                        Button("Clear local cache") {
                            navVM.popToRoot()
                            do {
                                try clearLocalCache(in: ctx)
                                vm.toastMessage = "Local cache cleared"
                            } catch {
                                vm.showAlert(
                                    "Error clearing local cache", error.localizedDescription)
                            }
                        }
                        Button("Logout") {
                            authVM.logout(ctx: ctx)
                        }
                        .foregroundStyle(IgniteColor.error)
                    }
                }
                .listRowBackground(IgniteColor.surface)
            }
            .igniteListColors()
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
            .navigationTitle("Hello \(nickname ?? "(no nickname)") 👋🏼")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await authVM.trySiwaLogin(vm: vm)
            }
        }
    }
}

#Preview {
    DebugInfoView()
        .environmentObject(AuthVM())
        .environmentObject(AppVM())
        .environmentObject(AvatarVM())
        .environmentObject(TeamWeekVM())
        .environmentObject(NavigationVM())
}

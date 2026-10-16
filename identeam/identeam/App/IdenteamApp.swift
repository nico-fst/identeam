import SwiftData
import SwiftUI

@main
struct IdenteamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var vm = AppVM()
    @StateObject private var authVM = AuthVM()
    @StateObject private var teamsVM = TeamsVM()
    // TeamWeekVM defined in TeamWeekView
    @StateObject private var navVM = NavigationVM()
    @StateObject private var cameraVM = CameraVM()
    @StateObject private var avatarVM = AvatarVM()
    @StateObject private var identingVM = IdentingVM()

    var sharedModelContainer = SharedModelConfig.makeContainer(for: .app)

    init() {
        IgniteAppearance.configure()
    }

    var body: some Scene {
        LaunchScreen {
            Image(.logoLong)
        } rootContent: {
            ContentView()
                .igniteColors()
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(authVM)
        .environmentObject(teamsVM)
        .environmentObject(vm)
        .environmentObject(navVM)
        .environmentObject(cameraVM)
        .environmentObject(avatarVM)
        .environmentObject(identingVM)
    }
}

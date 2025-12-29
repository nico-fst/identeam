//
//  identeamApp.swift
//  identeam
//
//  Created by Nico Stern on 23.11.25.
//

import SwiftData
import SwiftUI

@main
struct identeamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var vm = AppViewModel()
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var teamsVM = TeamsViewModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Team.self])
        let modelConfiguration = ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(authVM)
        .environmentObject(teamsVM)
        .environmentObject(vm)
    }
}

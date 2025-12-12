//
//  ContentView.swift
//  identeam
//
//  Created by Nico Stern on 23.11.25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @AppStorage("sessionToken") private var sessionToken: String = ""

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @AppStorage("deviceToken") var deviceToken: String?

    var body: some View {
        NavigationSplitView {
            Text("APNS DeviceToken: \(deviceToken)")
            Text("Session Token: \(sessionToken)")

            SignInWithAppleButtonView()
            CheckTokensButton()
        } detail: {
            Text("Select an item")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

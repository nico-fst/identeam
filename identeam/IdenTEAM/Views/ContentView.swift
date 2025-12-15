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

    var body: some View {
        NavigationStack {
            VStack {
                Text("BaseURL: \(AppConfig.apiBaseURL)")
                Text(authVM.authState.rawValue)
                switch authVM.authState {
                case .unknown:
                    ProgressView("Checking Session...")
                case .unauthenticated:
                    SignInWithAppleButtonView()
                case .authenticated:
                    CheckTokensButton()
                    Button("Logout") {
                        authVM.logout()
                    }
                }
            }
            .task {
                Task {
                    do { try await authVM.tryLogin() } catch {
                        authVM.authError = error.localizedDescription
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}

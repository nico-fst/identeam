//
//  ContentView.swift
//  identeam
//
//  Created by Nico Stern on 23.11.25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var teamsVM: TeamsViewModel
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ToastContainer(toastMessage: $vm.toastMessage) {
            TabView {
                Tab("Teams", systemImage: "person.2.fill") {
                    TeamsView()
                }
                Tab("Debug Info", systemImage: "info.circle.fill") {
                    DebugInfoView()
                }
            }
            .sheet(
                isPresented: Binding<Bool>(
                    get: {
                        (authVM.authState == .unauthenticated) || (authVM.authState == .enteringUserDetails)
                    },
                    set: { newValue in
                        // When the sheet is dismissed (newValue == false), reset auth state if needed
                        if newValue == false {
                            // Choose an appropriate state upon dismissal; adjust to your app's logic
                            if authVM.authState == .enteringUserDetails {
                                authVM.authState = .authenticated
                            }
                        }
                    }
                )
            ) {
                AuthSheetView()
            }
            .alert(item: $vm.alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                )
            }
        }
        .task {
            await authVM.trySiwaLogin(vm: vm)
            await teamsVM.reloadTeams(ctx: modelContext)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        return ContentView()
            .environmentObject(AppViewModel())
            .environmentObject(AuthViewModel())
            .environmentObject(TeamsViewModel())
    }
}

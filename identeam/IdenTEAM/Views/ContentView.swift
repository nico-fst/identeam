//
//  ContentView.swift
//  identeam
//
//  Created by Nico Stern on 23.11.25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var vm: AppViewModel

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
            .sheet(isPresented: $authVM.showLoginSheet) {
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
            await authVM.tryLogin()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let authVM = AuthViewModel()
        // authVM.showLoginSheet = false

        return ContentView()
            .environmentObject(AppViewModel())
            .environmentObject(authVM)
            .environmentObject(TeamsViewModel())
    }
}

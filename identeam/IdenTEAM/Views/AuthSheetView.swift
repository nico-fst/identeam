//
//  AuthSheetView.swift
//  identeam
//
//  Created by Nico Stern on 28.12.25.
//

import SwiftUI

struct AuthSheetView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack {
                if !authVM.showEnterUserDetails {
                    // step 1
                    SignInWithAppleButtonComponent()
                } else {
                    // step 2 (only after signing up)
                    VStack {
                        List {
                            TextField(
                                "Your Name",
                                text: $authVM.fullnameInput
                            )
                            TextField(
                                "Username",
                                text: $authVM.usernameInput
                            )
                        }

                        Text(authVM.signupError ?? "")
                            .foregroundColor(.red)

                        Button("Sign Up") {
                            Task { await authVM.tryChangeUserDetails() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationTitle("Login with Apple")
        }
        .interactiveDismissDisabled()
        .presentationDetents([.medium])
    }
}

#Preview {
    AuthSheetView()
        .environmentObject(AuthViewModel())
}

//
//  AuthSheetView.swift
//  identeam
//
//  Created by Nico Stern on 28.12.25.
//

import SwiftUI

struct AuthSheetView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var appVM: AppViewModel
    

    var body: some View {
        VStack {
            if authVM.authState != .enteringUserDetails {
                // step 1: Login / Sign up
                VStack {
                    SignInWithAppleButtonComponent()
                    
                    Text("or")
                        .opacity(0.5)
                        .padding()
                    
                    VStack(spacing: 5) {
                        List {
                            TextField(
                                "Email",
                                text: $authVM.emailInput
                            )
                            SecureField(
                                "Password",
                                text: $authVM.passwordInput
                            )
                            if authVM.authMode == .signup {
                                TextField(
                                    "Your Name",
                                    text: $authVM.fullnameInput
                                )
                                TextField(
                                    "Username",
                                    text: $authVM.usernameInput
                                )
                            }
                        }
                        
                        Button("Login") {
                            Task {
                                do {
                                    try await authVM.tryPasswordLoginOrSignup(
                                        authMode: .login,
                                        vm: appVM)
                                } catch AuthError.userNotFound {
                                    try await authVM.tryPasswordLoginOrSignup(authMode: .signup, vm: appVM)
                                } catch {
                                    authVM.signupError = error.localizedDescription
                                }
                            }
                        }
                        .padding()
                        .sensoryFeedback(.selection, trigger: authVM.authState)
                        .glassEffect(
                            .regular
                                .interactive()
                                .tint(Color("AccentColor").opacity(0.1))
                        )
                    }
                }
                .padding()
            } else if authVM.authState == .enteringUserDetails {
                // step 2 (only when signing up)
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

                    Button("Finish Sign up") {
                        Task { await authVM.tryChangeUserDetails() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            
            Text(authVM.signupError ?? "")
                .foregroundColor(.red)
        }
        .padding()
        .interactiveDismissDisabled()
        .presentationDetents([.medium])
    }
}

#Preview {
    AuthSheetView()
        .environmentObject(AuthViewModel())
}


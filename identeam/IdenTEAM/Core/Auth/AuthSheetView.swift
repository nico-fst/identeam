//
//  AuthSheetView.swift
//  identeam
//
//  Created by Nico Stern on 28.12.25.
//

import SwiftUI

struct AuthSheetView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var vm: AppViewModel
    

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
                        }
                        
                        Button {
                            Task {
                                do {
                                    try await authVM.tryPasswordLoginOrSignup(
                                        authMode: .login,
                                        vm: vm)
                                } catch AuthError.userNotFound {
                                    try await authVM.tryPasswordLoginOrSignup(authMode: .signup, vm: vm)
                                } catch {
                                    authVM.signupError = error.localizedDescription
                                }
                            }
                        } label: {
                            if authVM.isAuthing {
                                ProgressView().padding(10)
                            } else {
                                Text("Login").padding(10)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .glassEffect(.regular.interactive())
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

                    Button {
                        Task { await authVM.tryChangeUserDetails() }
                    } label: {
                        // show Loading icon waiting for backend
                        if authVM.isAuthing {
                            ProgressView().padding(10)
                        } else {
                            Text("Finish Sign Up").padding(10)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .glassEffect(.regular.interactive())
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
        .environmentObject(AppViewModel())
}


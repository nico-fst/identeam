import SwiftUI

struct AuthSheetView: View {
    @EnvironmentObject var authVM: AuthVM
    @EnvironmentObject var vm: AppVM

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
                            Group {
                                TextField(
                                    "Email",
                                    text: $authVM.emailInput
                                )
                                SecureField(
                                    "Password",
                                    text: $authVM.passwordInput
                                )
                            }
                            .listRowBackground(AppColor.surface)
                        }
                        .appListColors()

                        Button {
                            Task {
                                do {
                                    try await authVM.tryPasswordLoginOrSignup(
                                        authMode: .login,
                                        vm: vm)
                                } catch AuthError.userNotFound {
                                    try await authVM.tryPasswordLoginOrSignup(
                                        authMode: .signup, vm: vm)
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
                        .tint(.accent)
                        .foregroundStyle(AppColor.onAccent)
                        .glassEffect(.regular.tint(AppColor.selection).interactive())
                    }
                }
                .padding()
            } else if authVM.authState == .enteringUserDetails {
                // step 2 (only when signing up)
                VStack {
                    List {
                        Group {
                            TextField(
                                "Nickname",
                                text: $authVM.nicknameInput
                            )
                            TextField(
                                "Username",
                                text: $authVM.usernameInput
                            )
                        }
                        .listRowBackground(AppColor.surface)
                    }
                    .appListColors()

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
                    .tint(.accent)
                    .foregroundStyle(AppColor.onAccent)
                    .glassEffect(.regular.tint(AppColor.selection).interactive())
                }
                .padding()
            }

            Text(authVM.signupError ?? "")
                .foregroundColor(AppColor.error)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appColors()
        .interactiveDismissDisabled()
        .presentationDetents([.medium])
    }
}

#Preview {
    AuthSheetView()
        .environmentObject(AuthVM())
        .environmentObject(AppVM())
}

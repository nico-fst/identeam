import SwiftUI

struct TeamSettingsView: View {
    let slug: String
    let teamName: String
    let userID: String

    @Environment(\.dismiss) private var dismiss

    @State private var defaultTime: Date
    @State private var isSaving = false
    @State private var errorMessage = ""

    init(slug: String, teamName: String, userID: String) {
        self.slug = slug
        self.teamName = teamName
        self.userID = userID
        _defaultTime = State(
            initialValue: TeamReminderSettingsStore.shared.dateForPicker(
                userID: userID,
                slug: slug
            )
        )
    }

    var body: some View {
        List {
            Section {
                DatePicker(
                    "Default time",
                    selection: $defaultTime,
                    displayedComponents: .hourAndMinute
                )
            } header: {
                Text("Notifications")
            } footer: {
                VStack {
                    Text("IdenTEAM tries to schedule notifications intelligently based on your past idents.")
                    Text("This is the default time to schedule notifications on days when IdenTEAM still learns about your Ident behaviour.")
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .disabled(isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        await save()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
        }
        .presentationDetents([.medium])
    }

    private func save() async {
        errorMessage = ""
        isSaving = true
        defer { isSaving = false }

        TeamReminderSettingsStore.shared.setDefaultTime(
            defaultTime,
            userID: userID,
            slug: slug
        )

        do {
            _ = try await refreshLocalNotifications(
                slug: slug,
                teamName: teamName,
                userID: userID
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

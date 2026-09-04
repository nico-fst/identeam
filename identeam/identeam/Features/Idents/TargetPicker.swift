//
//  TargetPicker.swift
//  identeam
//
//  Created by Nico Stern on 19.05.26.
//

import SwiftUI
import SwiftData

struct TargetPicker: View {
    let slug: String
    let onChange: (Bool) -> Void // == new value set
    
    init(
        slug: String,
        initialTargetCount: Int = 3,
        onChange: @escaping (Bool) -> Void
    ) {
        self.slug = slug
        self.onChange = onChange
        _selectedTargetCount = State(initialValue: initialTargetCount)
    }
    
    @State private var selectedTargetCount: Int
    @State private var isSettingTarget = false
    @State private var settingError = ""
    
    @EnvironmentObject var vm: AppViewModel
    @AppStorage("userID") private var userID: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    
    var body: some View {
        VStack {
            Picker("Target", selection: $selectedTargetCount) {
                ForEach(1...7, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.wheel)
            
            Text(settingError)
                .foregroundStyle(.red)
        }
        .toolbar {
            // left: X
            ToolbarItem(placement: .topBarLeading) {
                Button {
                   onChange(false)
                } label: {
                    Image(systemName: "xmark")
                }
            }
            
            // right: Save
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        let success = await trySettingTarget(
                            slug: slug,
                            vm: vm,
                            ctx: ctx,
                        )
                        
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if isSettingTarget {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSettingTarget)
            }
        }
        .interactiveDismissDisabled()
        .navigationTitle("Set Target")
        .presentationDetents([.medium])
    }
    
    private func trySettingTarget(
        slug: String,
        vm: AppViewModel,
        ctx: ModelContext,
    ) async -> Bool {
        guard selectedTargetCount != 0 else {
            settingError = "You must select a value first"
            return false
        }
        
        var notificationsScheduled = false
        
        settingError = ""
        isSettingTarget = true
        defer { isSettingTarget = false }

        do {
            try await TeamAPI.shared.setTarget(
                slug: slug,
                dateStart: Date(),
                count: selectedTargetCount
            )
           
            // schedule notifications
            
            let teamName = try? ctx.fetch(
                FetchDescriptor<Team>(
                    predicate: #Predicate<Team> { team in
                        team.slug == slug
                    }
                )
            ).first?.name

            if try await refreshLocalNotifications(
                slug: slug,
                teamName: teamName ?? slug,
                userID: userID
            ) > 0 {
                notificationsScheduled = true
            }
        } catch {
            settingError = error.localizedDescription
            return false
        }

        vm.toastMessage = "Target set\(notificationsScheduled ? " ⋅ Notifications scheduled" : "")"

        onChange(true)
        return true
    }
}

#Preview {
    TargetPicker(
        slug: "die-kanten",
        onChange: { _ in }
    )
    .environmentObject(AppViewModel())
}

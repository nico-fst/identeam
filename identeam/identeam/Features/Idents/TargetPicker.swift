//
//  TargetPicker.swift
//  identeam
//
//  Created by Nico Stern on 19.05.26.
//

import SwiftUI
import SwiftData

struct TargetPicker: View {
    let team: Team
    let onChange: (Bool) -> Void
    
    @State private var selectedTargetCount: Int = 3
    @State private var isSettingTarget = false
    
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    
    var body: some View {
        Picker("Target", selection: $selectedTargetCount) {
            ForEach(1...7, id: \.self) { count in
                Text("\(count)").tag(count)
            }
        }
        .pickerStyle(.wheel)
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
                        await trySettingTarget(
                            slug: team.slug,
                            vm: vm,
                            ctx: ctx,
                        )
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
        .navigationTitle("Set Target")
    }
    
    func trySettingTarget(
        slug: String,
        vm: AppViewModel,
        ctx: ModelContext,
    ) async {
        guard selectedTargetCount != 0 else {
            vm.showAlert("Error setting target", "You must select a value first")
            return
        }
        
        isSettingTarget = true
        defer { isSettingTarget = false }

        do {
            try await TeamAPI.shared.setTarget(
                slug: slug,
                dateStart: Date(),
                count: selectedTargetCount
            )
        } catch {
            vm.showAlert("Error setting Target", error.localizedDescription)
            return
        }

        vm.toastMessage = "Target set"

        onChange(true)
    }
}

#Preview {
    TargetPicker(
        team: Team(name: "Die Kanten", slug: "die-kanten", details: "Hier sind Kanten drin"),
        onChange: { _ in }
    )
    .environmentObject(AppViewModel())
}

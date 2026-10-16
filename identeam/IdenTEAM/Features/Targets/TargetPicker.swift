import SwiftData
import SwiftUI

struct TargetPicker: View {
    let slug: String
    @StateObject private var targetPickerVM: TargetPickerVM
    let onChange: (Bool) -> Void  // == new value set

    init(
        slug: String,
        referenceDate: Date = TargetPlanning.firstPlannableWeek(),
        initialSelectedDays: [Date] = [],
        onChange: @escaping (Bool) -> Void
    ) {
        self.slug = slug
        _targetPickerVM = StateObject(
            wrappedValue: TargetPickerVM(
                referenceDate: referenceDate,
                initialSelectedDays: initialSelectedDays
            ))
        self.onChange = onChange
    }

    @EnvironmentObject var vm: AppVM
    @AppStorage("userID") private var userID: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    private var cal: Calendar {
        AppCalendar.calendar
    }
    private var daysOfWeek: [Date] {
        AppCalendar.datesInWeek(containing: targetPickerVM.referenceDate)
    }

    var body: some View {
        List(selection: $targetPickerVM.selectedDays) {
            Group {
                Section {
                    HStack {
                        Button {
                            targetPickerVM.changeWeek(by: -7)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(
                            !TargetPlanning.canSetTargetWeek(
                                cal.date(
                                    byAdding: .day, value: -7, to: targetPickerVM.referenceDate)!
                            )
                        )

                        Spacer()

                        Text(TargetPlanning.weekName(for: targetPickerVM.referenceDate))
                            .font(.nunito(.headline))

                        Spacer()

                        Button {
                            targetPickerVM.changeWeek(by: 7)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .disabled(targetPickerVM.isSettingTarget)
                    .buttonStyle(.glassProminent)
                    .tint(.accent)
                    .foregroundStyle(IgniteColor.onAccent)
                }

                Section {
                    if targetPickerVM.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(
                                day.formatted(
                                    .dateTime
                                        .weekday(.abbreviated)
                                        .day()
                                        .month()
                                )
                            )
                            .tag(day)
                        }
                    }
                } header: {
                    Text("Select Ident days")
                } footer: {
                    if targetPickerVM.settingError.isEmpty {
                        Text("Your target will be \(targetPickerVM.selectedDays.count)")
                    } else {
                        Text(targetPickerVM.settingError)
                            .foregroundStyle(IgniteColor.error)
                    }
                }

                if !targetPickerVM.settingError.isEmpty {
                    Section {
                        if !targetPickerVM.isLoading && !targetPickerVM.hasLoaded {
                            Button("Retry") {
                                Task {
                                    await targetPickerVM.loadTargetDays(slug: slug, userID: userID)
                                }
                            }
                        }
                    }
                }
            }
            .listRowBackground(IgniteColor.surface)
        }
        .igniteListColors()
        .environment(\.editMode, .constant(.active))
        .disabled(targetPickerVM.isSettingTarget)
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
                        let success = await targetPickerVM.trySettingTarget(
                            slug: slug,
                            vm: vm,
                            ctx: ctx,
                            userID: userID,
                        )

                        if success {
                            onChange(true)
                            dismiss()
                        }
                    }
                } label: {
                    if targetPickerVM.isSettingTarget {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                            .foregroundStyle(IgniteColor.onAccent)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accent)
                .foregroundStyle(IgniteColor.onAccent)
                .disabled(
                    targetPickerVM.isSettingTarget || targetPickerVM.isLoading
                        || !targetPickerVM.hasLoaded)
            }
        }
        .environment(\.timeZone, cal.timeZone)
        .task(id: targetPickerVM.referenceDate) {
            await targetPickerVM.loadTargetDays(slug: slug, userID: userID)
        }
        .interactiveDismissDisabled()
        .navigationTitle("Set Target")
        .presentationDetents([.large])
    }
}

#Preview {
    TargetPicker(
        slug: "die-kanten",
        onChange: { _ in }
    )
    .environmentObject(AppVM())
}

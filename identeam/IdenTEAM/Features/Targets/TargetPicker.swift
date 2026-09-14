import SwiftUI
import SwiftData

struct TargetPicker: View {
    let slug: String
    @StateObject private var model: TargetPickerViewModel
    let onChange: (Bool) -> Void // == new value set

    init(
        slug: String,
        referenceDate: Date = TargetPlanning.firstPlannableWeek(),
        initialSelectedDays: [Date] = [],
        onChange: @escaping (Bool) -> Void
    ) {
        self.slug = slug
        _model = StateObject(wrappedValue: TargetPickerViewModel(
            referenceDate: referenceDate,
            initialSelectedDays: initialSelectedDays
        ))
        self.onChange = onChange
    }

    @EnvironmentObject var vm: AppViewModel
    @AppStorage("userID") private var userID: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    private var cal: Calendar {
        AppCalendar.calendar
    }
    private var daysOfWeek: [Date] {
        AppCalendar.datesInWeek(containing: model.referenceDate)
    }

    var body: some View {
        List(selection: $model.selectedDays) {
            Section {
                HStack {
                    Button {
                        model.changeWeek(by: -7)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(
                        !TargetPlanning.canSetTargetWeek(
                            cal.date(byAdding: .day, value: -7, to: model.referenceDate)!
                        )
                    )

                    Spacer()

                    Text(TargetPlanning.weekName(for: model.referenceDate))
                        .font(.headline)

                    Spacer()

                    Button {
                        model.changeWeek(by: 7)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(model.isSettingTarget)
                .buttonStyle(.glassProminent)
            }

            Section {
                if model.isLoading {
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
                if model.settingError.isEmpty {
                    Text("Your target will be \(model.selectedDays.count)")
                } else {
                    Text(model.settingError)
                        .foregroundStyle(.red)
                }
            }

            if !model.settingError.isEmpty {
                Section {
                    if !model.isLoading && !model.hasLoaded {
                        Button("Retry") {
                            Task {
                                await model.loadTargetDays(slug: slug, userID: userID)
                            }
                        }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .disabled(model.isSettingTarget)
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
                        let success = await model.trySettingTarget(
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
                    if model.isSettingTarget {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isSettingTarget || model.isLoading || !model.hasLoaded)
            }
        }
        .environment(\.timeZone, cal.timeZone)
        .task(id: model.referenceDate) {
            await model.loadTargetDays(slug: slug, userID: userID)
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
    .environmentObject(AppViewModel())
}

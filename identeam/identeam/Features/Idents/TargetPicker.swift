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
    @State private var referenceDate: Date
    let onChange: (Bool) -> Void // == new value set

    init(
        slug: String,
        referenceDate: Date = ReminderSchedulePlanner.firstPlannableWeek(),
        initialSelectedDays: [Date] = [],
        onChange: @escaping (Bool) -> Void
    ) {
        self.slug = slug
        _referenceDate = State(initialValue: max(
            ReminderSchedulePlanner.startOfWeek(containing: referenceDate),
            ReminderSchedulePlanner.firstPlannableWeek()
        ))
        self.onChange = onChange
        _selectedDays = State(initialValue: Set(initialSelectedDays))
    }
    
    @State private var selectedDays = Set<Date>()
    @State private var isLoading = true
    @State private var hasLoaded = false
    @State private var isSettingTarget = false
    @State private var settingError = ""
    
    @EnvironmentObject var vm: AppViewModel
    @AppStorage("userID") private var userID: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    
    private var cal: Calendar {
        ReminderSchedulePlanner.calendar
    }
    private var daysOfWeek: [Date] {
        guard let monday = cal.dateInterval(of: .weekOfYear, for: referenceDate)?.start
        else { return [] }
        
        return (0..<7).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: monday)
        }
    }
    
    private var kw: Int {
        cal.component(.weekOfYear, from: referenceDate)
    }
    
    private var weekName: String {
        let thisWeek = ReminderSchedulePlanner.startOfWeek(containing: Date())
        let weekStart = ReminderSchedulePlanner.startOfWeek(containing: referenceDate)

        if weekStart == thisWeek {
            return "This week"
        }

        if let nextWeek = cal.date(byAdding: .day, value: 7, to: thisWeek),
           weekStart == nextWeek {
            return "Next week"
        }
        
        if let nextWeek = cal.date(byAdding: .day, value: 14, to: thisWeek),
           weekStart == nextWeek {
            return "The week after next"
        }

        return "Week of \(ReminderSchedulePlanner.dateString(weekStart))"
    }
    
    var body: some View {
        List(selection: $selectedDays) {
            Section {
                HStack {
                    Button {
                        changeWeek(by: -7)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(
                        !ReminderSchedulePlanner.canSetTargetWeek(
                            cal.date(byAdding: .day, value: -7, to: referenceDate)!
                        )
                    )

                    Spacer()

                    Text(weekName)
                        .font(.headline)

                    Spacer()

                    Button {
                        changeWeek(by: 7)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(isSettingTarget)
                .buttonStyle(.glassProminent)
            }

            Section {
                if isLoading {
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
                if settingError.isEmpty {
                    Text("Your target will be \(selectedDays.count)")
                } else {
                    Text(settingError)
                        .foregroundStyle(.red)
                }
            }

            if !settingError.isEmpty {
                Section {
                    if !isLoading && !hasLoaded {
                        Button("Retry") {
                            Task {
                                await loadTargetDays()
                            }
                        }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .disabled(isSettingTarget)
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
                       
                        // TODO redundant
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
                .disabled(isSettingTarget || isLoading || !hasLoaded)
            }
        }
        .environment(\.timeZone, cal.timeZone)
        .task(id: referenceDate) {
            await loadTargetDays()
        }
        .interactiveDismissDisabled()
        .navigationTitle("Set Target")
        .presentationDetents([.large])
    }
    
    private func changeWeek(by days: Int) {
        isLoading = true
        hasLoaded = false
        selectedDays = []
        referenceDate = cal.date(byAdding: .day, value: days, to: referenceDate)!
    }

    @MainActor
    private func loadTargetDays() async {
        isLoading = true
        hasLoaded = false
        settingError = ""
        do {
            let week = try await TeamAPI.shared.fetchTeamWeek(slug: slug, date: referenceDate)
            guard !Task.isCancelled else { return }
            selectedDays = Set(week.members.first { $0.user.userID == userID }?.targetDays ?? [])
            isLoading = false
            hasLoaded = true
        } catch {
            guard !Task.isCancelled else { return }
            isLoading = false
            settingError = error.localizedDescription
        }
    }

    @MainActor
    private func trySettingTarget(
        slug: String,
        vm: AppViewModel,
        ctx: ModelContext,
    ) async -> Bool {
        var notificationsScheduled = false
        
        settingError = ""
        isSettingTarget = true
        defer { isSettingTarget = false }

        do {
            try await TeamAPI.shared.setTarget(
                slug: slug,
                dateStart: referenceDate,
                targetDays: Array(selectedDays)
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
                userID: userID,
                dateStart: referenceDate
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

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
        referenceDate: Date = ReminderSchedulePlanner.nextMonday(after: Date()),
        initialSelectedDays: [Date] = [],
        onChange: @escaping (Bool) -> Void
    ) {
        self.slug = slug
        _referenceDate = State(initialValue: max(
            ReminderSchedulePlanner.startOfWeek(containing: referenceDate),
            ReminderSchedulePlanner.nextMonday(after: Date())
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
    
    var body: some View {
        VStack {
            HStack {
                Button { changeWeek(by: -7) } label: { Image(systemName: "chevron.left") }
                    .disabled(!ReminderSchedulePlanner.isFutureWeek(cal.date(byAdding: .day, value: -7, to: referenceDate)!))
                Spacer()
                Text("Week of \(ReminderSchedulePlanner.dateString(referenceDate))")
                Spacer()
                Button { changeWeek(by: 7) } label: { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal)
            .disabled(isSettingTarget)
            if isLoading { ProgressView() }
            List(selection: $selectedDays) {
                Section("Dates in KW\(kw)") {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(
                            day.formatted(
                                .dateTime
                                    .weekday(.wide)
                                    .day()
                                    .month()
                            )
                        )
                        .tag(day)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .disabled(isLoading || !hasLoaded || isSettingTarget)

            Text(settingError)
                .foregroundStyle(.red)
            if !isLoading && !hasLoaded {
                Button("Retry") { Task { await loadTargetDays() } }
            }
        }
        .padding()
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
        .task(id: referenceDate) { await loadTargetDays() }
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

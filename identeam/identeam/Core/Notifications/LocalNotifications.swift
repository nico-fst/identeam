//
//  LocalNotifications.swift
//  identeam
//
//  Created by Nico Stern on 03.06.26.
//

import Foundation
import UserNotifications

@MainActor
@discardableResult
func refreshLocalNotifications(
    slug: String,
    teamName: String,
    userID: String,
    dateStart: Date = ReminderSchedulePlanner.nextMonday(after: Date())
) async throws -> Int {
    let week = try await TeamAPI.shared.fetchTeamWeek(slug: slug, date: dateStart)
    let targetDays = week.members.first { $0.user.userID == userID }?.targetDays ?? []
    let intelligentSuggestions =
        (try? await LocalNotificationAPI.shared.fetchNotifications(slug: slug, dateStart: dateStart))
        ?? []
    let defaultTime = TeamReminderSettingsStore.shared.defaultTime(
        userID: userID,
        slug: slug
    )
    let reminders = ReminderSchedulePlanner.remindersForWeek(
        intelligentSuggestions: intelligentSuggestions,
        defaultTime: defaultTime,
        teamName: teamName,
        dateStart: dateStart,
        targetDays: targetDays
    )

    try await scheduleLocalNotifications(reminders, slug: slug, dateStart: dateStart)
    return reminders.count
}

func scheduleLocalNotifications(_ reminders: [LocalReminderDTO], slug: String, dateStart: Date) async throws {
    let center = UNUserNotificationCenter.current()
    
    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
    guard granted else { return }
    
    let weekStart = ReminderSchedulePlanner.startOfWeek(containing: dateStart)
    let weekEnd = ReminderSchedulePlanner.calendar.date(byAdding: .day, value: 7, to: weekStart)!
    let weekPrefix = "identeam-reminder-\(slug)-\(ReminderSchedulePlanner.dateString(weekStart))-"
    // Replace only this week; keep reminders for other planned weeks.
    let oldRequests = await center.pendingNotificationRequests()
    let oldIDs = oldRequests
        .filter { request in
            if request.identifier.hasPrefix(weekPrefix) { return true }
            let legacyPrefix = "identeam-reminder-\(slug)-"
            guard request.identifier.hasPrefix(legacyPrefix),
                  Double(request.identifier.dropFirst(legacyPrefix.count)) != nil,
                  let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let date = trigger.nextTriggerDate() else { return false }
            return date >= weekStart && date < weekEnd
        }
        .map(\.identifier)
    center.removePendingNotificationRequests(withIdentifiers: oldIDs)
    
    for reminder in reminders {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        
        var components = ReminderSchedulePlanner.calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.date
        )
        
        components.timeZone = ReminderSchedulePlanner.calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "\(weekPrefix)\(reminder.date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        try await center.add(request)
    }
}

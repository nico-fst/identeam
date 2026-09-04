//
//  LocalNotifications.swift
//  identeam
//
//  Created by Nico Stern on 03.06.26.
//

import Foundation
import UserNotifications

@discardableResult
func refreshLocalNotifications(
    slug: String,
    teamName: String,
    userID: String
) async throws -> Int {
    let intelligentSuggestions =
        (try? await LocalNotificationAPI.shared.fetchUpcomingNotifications(slug: slug))
        ?? []
    let defaultTime = TeamReminderSettingsStore.shared.defaultTime(
        userID: userID,
        slug: slug
    )
    let reminders = ReminderSchedulePlanner.remindersForUpcomingWeek(
        intelligentSuggestions: intelligentSuggestions,
        defaultTime: defaultTime,
        teamName: teamName
    )

    try await scheduleLocalNotifications(reminders, slug: slug)
    return reminders.count
}

func scheduleLocalNotifications(_ reminders: [LocalReminderDTO], slug: String) async throws {
    let center = UNUserNotificationCenter.current()
    
    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
    guard granted else { return }
    
    // replace old reminders
    let oldRequests = await center.pendingNotificationRequests()
    let oldIDs = oldRequests
        .map(\.identifier)
        .filter { $0.hasPrefix("identeam-reminder-\(slug)") }
    center.removePendingNotificationRequests(withIdentifiers: oldIDs)
    
    for reminder in reminders {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.date
        )
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "identeam-reminder-\(slug)-\(reminder.date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        try await center.add(request)
    }
}

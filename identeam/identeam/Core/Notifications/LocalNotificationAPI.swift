//
//  LocalNotificationAPI.swift
//  identeam
//
//  Created by Nico Stern on 03.06.26.
//

import Foundation

class LocalNotificationAPI {
    static let shared = LocalNotificationAPI()
    
    func fetchUpcomingNotifications(slug: String) async throws -> [LocalReminderDTO] {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/\(slug)/week/notifications"
        )
        
        let response: BackendResponse<[LocalReminderDTO]> = try await API.shared.getToBackend(url: url)
        
        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw APIError.backend(response.message)
        }
    }
}

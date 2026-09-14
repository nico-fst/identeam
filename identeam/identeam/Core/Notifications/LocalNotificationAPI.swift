import Foundation

class LocalNotificationAPI {
    static let shared = LocalNotificationAPI()
    
    func fetchNotifications(slug: String, dateStart: Date) async throws -> [LocalReminderDTO] {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/\(slug)/week/notifications"
        ).appending(queryItems: [URLQueryItem(name: "dateStart", value: AppCalendar.dateString(dateStart))])
        
        let response: BackendResponse<[LocalReminderDTO]> = try await API.shared.getToBackend(url: url)
        
        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw APIError.backend(response.message)
        }
    }
}

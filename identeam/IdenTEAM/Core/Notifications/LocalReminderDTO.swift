import Foundation

nonisolated struct LocalReminderDTO: Decodable {
    let title: String
    let body: String
    let date: Date
}


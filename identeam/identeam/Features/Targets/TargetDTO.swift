import Foundation

struct TargetDTO: Decodable {
    let timeStart: Date
    let targetDays: [String]
}

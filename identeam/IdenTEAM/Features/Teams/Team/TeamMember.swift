import Foundation
import SwiftData

struct TeamMemberDTO: Decodable {
    let user: UserDTO
    let targetDays: [String] // yyy-mm-dd
    let idents: [IdentDTO]
}

@Model
final class TeamMember: Identifiable {
    var id = UUID()
    var user: User
    var targetDays: [Date]
    var idents: [Ident]

    init(
        user: User,
        targetDays: [String],
        idents: [Ident]
    ) {
        self.user = user

        self.targetDays = targetDays.compactMap(AppCalendar.parseDate)
        self.idents = idents
    }

    convenience init(dto: TeamMemberDTO) {
        self.init(
            user: User(dto: dto.user),
            targetDays: dto.targetDays,
            idents: dto.idents.map { Ident(dto: $0) }
        )
    }
}

extension TeamMember {
    static var templateGretaKanten: TeamMember {
        TeamMember(
            user: .templateGreta,
            targetDays: ["2026-02-02", "2026-02-03", "2026-02-04"],
            idents: [
                .templateGym,
                .templateOtherGym,
            ]
        )
    }

    static var templateNicoKanten: TeamMember {
        TeamMember(
            user: .templateNico,
            targetDays: ["2026-02-02", "2026-02-04"],
            idents: [
                .templateEvenOtherGym,
            ]
        )
    }
}


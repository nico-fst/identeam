import CoreGraphics
import Foundation

/// Value data for the weekly UI. Identity belongs to the user and Ident, never a SwiftData reload.
nonisolated struct TeamWeekPresentation: Equatable {  // equatable: 2 instances can be compared
    struct Member: Identifiable, Equatable {
        let id: String
        let name: String
        let targets: [Date]
        let idents: [Entry]

        var target: Int { targets.count }
        var completed: Int { idents.count }
        var progress: Double { target > 0 ? Double(completed) / Double(target) : 0 }
        var remaining: Int { max(0, target - completed) }
    }

    struct Entry: Identifiable, Equatable {
        let id: String
        let time: Date
    }

    enum MarkKind: Int, Equatable { case completed, planned, missed }

    enum MarkInteraction: Equatable {
        case image(String)
        case explanation
    }

    struct Mark: Identifiable, Equatable {
        let id: String
        let memberID: String
        let day: Int
        let kind: MarkKind
        let identID: String?

        func thumbnailIdentID(showImages: Bool) -> String? {
            showImages && kind == .completed ? identID : nil
        }

        var interaction: MarkInteraction {
            identID.map(MarkInteraction.image) ?? .explanation
        }
    }

    enum Scenario: String, CaseIterable {
        case setGoal, nearlyFinished, behind, catchingUp, newWeek, personallyOnTrack, teamOnTrack

        var caption: String {
            switch self {
            case .setGoal: "Ziellos"
            case .nearlyFinished: "Am Edgen"
            case .behind: "Lowperformer"
            case .catchingUp: "Besser als du"
            case .newWeek: "Am Durchstarten"
            case .personallyOnTrack: "Von dir outperformed"
            case .teamOnTrack: "Am Performen"
            }
        }

        var isBold: Bool {
            [.nearlyFinished, .behind, .catchingUp].contains(self)
        }
    }

    let weekStart: Date
    let members: [Member]
    let currentUserID: String
    let streak: Int
    let now: Date

    var title: String {
        let current = AppCalendar.startOfWeek(containing: now)
        let delta =
            AppCalendar.calendar.dateComponents([.weekOfYear], from: current, to: weekStart)
            .weekOfYear ?? 0
        switch delta {
        case 0: return "Diese Woche"
        case -1: return "Letzte Woche"
        case 1: return "Nächste Woche"
        default: return "Woche"
        }
    }

    static func dateRange(for date: Date) -> String {
        let days = AppCalendar.datesInWeek(containing: date)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = AppCalendar.calendar.timeZone
        formatter.dateFormat = "d. MMM"
        let sameMonth = AppCalendar.calendar.isDate(
            days[0], equalTo: days[6], toGranularity: .month)
        let start =
            sameMonth
            ? "\(AppCalendar.calendar.component(.day, from: days[0]))."
            : formatter.string(from: days[0])
        return "\(start)–\(formatter.string(from: days[6]))"
    }

    var dates: [Date] { AppCalendar.datesInWeek(containing: weekStart) }
    var currentMember: Member? { members.first { $0.id == currentUserID } }
    var legendMembers: [Member] {
        members.filter { $0.id == currentUserID } + members.filter { $0.id != currentUserID }
    }
    var personalProgress: Double { min(1, currentMember?.progress ?? 0) }
    var target: Int { members.reduce(0) { $0 + $1.target } }
    var completed: Int { members.reduce(0) { $0 + $1.completed } }
    var remaining: Int { max(0, target - completed) }
    var progress: Double { target > 0 ? min(1, Double(completed) / Double(target)) : 0 }
    var isPast: Bool { weekStart < AppCalendar.startOfWeek(containing: now) }
    var isFuture: Bool { weekStart > AppCalendar.startOfWeek(containing: now) }
    /// Round to the five existing cut designs: light, corner, medium, deep and full dark.
    var darkCutStage: Int { Int((progress * 4).rounded()) }
    var darkHeader: Bool { darkCutStage >= 2 }
    var darkInfo: Bool { darkCutStage >= (scenario.isBold ? 3 : 2) }
    var darkWeek: Bool { darkCutStage >= 3 }
    var darkStreak: Bool { darkCutStage >= 2 }

    /// Approved priority: unset personal goal, untouched week, one remaining, personal catch-up,
    /// missed scheduled days, personal on-course, then team on-course.
    var scenario: Scenario {
        if let currentMember, currentMember.target == 0, !isPast { return .setGoal }
        if completed == 0 { return .newWeek }
        if target > 0, remaining == 1 { return .nearlyFinished }
        if let currentMember, currentMember.remaining > 0 {
            let others = members.filter { $0.id != currentUserID && $0.target > 0 }
            if !others.isEmpty, others.allSatisfy({ $0.remaining <= 1 }),
                others.allSatisfy({ $0.progress > currentMember.progress })
            {
                return .catchingUp
            }
        }
        if marks.contains(where: { $0.kind == .missed }), remaining > 0 { return .behind }
        if let currentMember, currentMember.completed > 0, currentMember.remaining > 0 {
            let others = members.filter { $0.id != currentUserID && $0.target > 0 }
            if others.isEmpty || others.contains(where: { $0.progress < currentMember.progress }) {
                return .personallyOnTrack
            }
        }
        return .teamOnTrack
    }

    var rankedMembers: [Member] {
        members.sorted {
            if $0.progress != $1.progress { return $0.progress > $1.progress }
            return $0.id < $1.id
        }
    }

    var marks: [Mark] {
        let calendar = AppCalendar.calendar
        let today = calendar.startOfDay(for: now)
        return members.flatMap { member in
            dates.enumerated().flatMap { day, date -> [Mark] in
                let entries = member.idents.filter { calendar.isDate($0.time, inSameDayAs: date) }
                    .sorted { $0.time == $1.time ? $0.id < $1.id : $0.time < $1.time }
                if !entries.isEmpty {
                    return entries.map {
                        Mark(
                            id: "ident-\(member.id)-\($0.id)", memberID: member.id, day: day,
                            kind: .completed, identID: $0.id)
                    }
                }
                guard member.targets.contains(where: { calendar.isDate($0, inSameDayAs: date) })
                else {
                    return []
                }
                return [
                    Mark(
                        id: "plan-\(member.id)-\(AppCalendar.dateString(date))",
                        memberID: member.id, day: day,
                        kind: date < today ? .missed : .planned, identID: nil)
                ]
            }
        }
    }

    func marks(on day: Int, memberID: String? = nil) -> [Mark] {
        let matching = marks.filter {
            $0.day == day && (memberID == nil || $0.memberID == memberID)
        }
        return matching.sorted { lhs, rhs in
            if (lhs.kind == .missed) != (rhs.kind == .missed) { return lhs.kind != .missed }
            let left = members.firstIndex { $0.id == lhs.memberID } ?? 0
            let right = members.firstIndex { $0.id == rhs.memberID } ?? 0
            return left == right ? lhs.id < rhs.id : left < right
        }
    }

    func todayIndex() -> Int? {
        dates.firstIndex { AppCalendar.calendar.isDate($0, inSameDayAs: now) }
    }
}

nonisolated struct TeamWeekGeometry {
    let width: CGFloat
    let memberCount: Int
    let detailed: Bool
    var personWidth: CGFloat { detailed ? 48 : 0 }
    var summaryWidth: CGFloat { detailed ? 68 : 0 }
    var dayWidth: CGFloat { max(1, (width - personWidth - summaryWidth) / 7) }
    var dayHeaderHeight: CGFloat { 34 }
    var rowHeight: CGFloat { 84 }
    var height: CGFloat { detailed ? dayHeaderHeight + CGFloat(memberCount) * rowHeight : 114 }

    func dayX(_ day: Int) -> CGFloat { personWidth + (CGFloat(day) + 0.5) * dayWidth }
    func rowY(_ member: Int) -> CGFloat { dayHeaderHeight + (CGFloat(member) + 0.5) * rowHeight }
    func markPosition(day: Int, member: Int, stack: Int, count: Int) -> CGPoint {
        let dx = (CGFloat(stack) - CGFloat(count - 1) / 2) * 8
        let dy = CGFloat(stack) * 6
        return CGPoint(
            x: dayX(day) + dx,
            y: detailed ? rowY(member) + dy : dayHeaderHeight + 30 + dy)
    }

    func todayFrame(_ day: Int) -> CGRect {
        CGRect(
            x: personWidth + CGFloat(day) * dayWidth, y: 0,
            width: dayWidth, height: height)
    }
}

/// Interpolate during the drag and deceleration instead of resizing only after a page settles.
nonisolated enum TeamWeekPagerGeometry {
    static func height(_ heights: [Int: CGFloat], progress: CGFloat) -> CGFloat {
        let position = min(4, max(0, progress))
        let lower = Int(position.rounded(.down))
        let upper = min(4, lower + 1)
        let fraction = position - CGFloat(lower)
        let start = heights[lower] ?? 310
        return start + ((heights[upper] ?? start) - start) * fraction
    }
}

/// Screen-relative cut geometry, independent of the scroll content's changing height.
nonisolated enum TeamWeekBackdropGeometry {
    static func vertices(stage: Int, size: CGSize, scrollOffset: CGFloat = 0) -> [CGPoint] {
        guard stage >= 1 else { return [] }
        let width = size.width
        let height = size.height
        if stage >= 4 {
            return [
                .zero, CGPoint(x: width, y: 0), CGPoint(x: width, y: height),
                CGPoint(x: 0, y: height),
            ]
        }
        let restingDepth: CGFloat =
            stage == 1
            ? -width * 0.35
            : stage == 2
                ? max(260, height * 0.28)
                : max(320, height - width * 0.45)
        // Scrolling moves the diagonal, never the viewport's top edge. Negative offsets are
        // the native pull-down bounce and move the edge continuously in the other direction.
        let depth = restingDepth - scrollOffset
        return [
            CGPoint(x: 0, y: depth), .zero, CGPoint(x: width, y: 0),
            CGPoint(x: width, y: depth + width),
        ]
    }
}

/// Keep the golden halo's footprint stable and ramp only its intensity over three weeks.
nonisolated enum TeamWeekStreakGlow {
    static func strength(for streak: Int) -> Double {
        Double(min(3, max(0, streak))) / 3
    }
}

nonisolated struct TeamWeekStreakFlames {
    let streak: Int
    var showsLarge: Bool { streak >= 2 }
    var showsSmall: Bool { streak == 1 || streak >= 3 }
}

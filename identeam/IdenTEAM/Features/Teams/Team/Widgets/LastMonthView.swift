import SwiftUI

/// Shared personal month calendar for the app and WidgetKit extension.
struct LastMonthView: View {
    let month: Date
    let personalWeeks: [PersonalWeek]
    var referenceDate = Date()
    var dayHeight: CGFloat = 32
    var rowSpacing: CGFloat = 8

    var allIdents: [Date] {
        personalWeeks.flatMap(\.identDates)
    }

    var body: some View {
        VStack(spacing: rowSpacing) {
            ForEach(AppCalendar.weekStartsInMonth(containing: month), id: \.self) { weekStart in
                let week = calendarDays(in: weekStart)
                let weekReachedGoal = personalWeeks.contains {
                    $0.goalReached
                        && AppCalendar.calendar.isDate($0.weekStart, inSameDayAs: weekStart)
                }

                HStack(spacing: 2) {
                    ForEach(week.indices, id: \.self) { index in
                        ZStack {
                            Color.clear
                            if let date = week[index] {
                                if isIdent(on: date) {
                                    Image("Flash")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(AppColor.success)
                                } else if isTarget(on: date) {
                                    if isMissedTarget(on: date) {
                                        FlashShape()
                                            .strokeBorder(AppColor.error, lineWidth: 1)
                                    } else {
                                        FlashShape()
                                            .strokeBorder(.accent, lineWidth: 1)
                                    }
                                } else {
                                    Text(String(AppCalendar.calendar.component(.day, from: date)))
                                        .monospacedDigit()
                                        .foregroundStyle(AppColor.text)
                                }

                                if AppCalendar.calendar.isDate(date, inSameDayAs: referenceDate) {
                                    Circle()
                                        .stroke(.accent.opacity(0.75), lineWidth: 1)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: dayHeight)
                    }
                }
                .background {
                    if weekReachedGoal {
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: dayHeight / 2, style: .continuous)
                                .fill(AppColor.successSurface)
                                .padding(
                                    backgroundInsets(in: weekStart, rowWidth: geometry.size.width)
                                )
                                .padding(.vertical, -2)
                        }
                    }
                }
            }
        }
    }

    func isIdent(on date: Date) -> Bool {
        allIdents.contains {
            AppCalendar.calendar.isDate($0, inSameDayAs: date)
        }
    }

    func isMissedTarget(on date: Date) -> Bool {
        !isIdent(on: date)
            && isTarget(on: date)
            && date < AppCalendar.calendar.startOfDay(for: referenceDate)
    }

    func isTarget(on date: Date) -> Bool {
        personalWeeks.contains { week in
            week.targetDates.contains {
                AppCalendar.calendar.isDate($0, inSameDayAs: date)
            }
        }
    }

    func calendarDays(in weekStart: Date) -> [Date?] {
        AppCalendar.datesInWeek(containing: weekStart).map { date in
            AppCalendar.calendar.isDate(date, equalTo: month, toGranularity: .month)
                ? date : nil
        }
    }

    func backgroundInsets(in weekStart: Date, rowWidth: CGFloat) -> EdgeInsets {
        let days = calendarDays(in: weekStart)
        let leadingDays = days.prefix { $0 == nil }.count
        let trailingDays = days.reversed().prefix { $0 == nil }.count
        // Seven equal day cells with the same two-point spacing as the row.
        let dayStride = (rowWidth - 6 * 2) / 7 + 2
        return EdgeInsets(
            top: 0,
            leading: CGFloat(leadingDays) * dayStride,
            bottom: 0,
            trailing: CGFloat(trailingDays) * dayStride
        )
    }
}

#Preview("March 2026 · Six weeks") {
    LastMonthView(
        month: PersonalWeek.templateMonth,
        personalWeeks: PersonalWeek.templateWeeks
    )
    .padding()
}

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
            ForEach(calendarWeeks, id: \.self) { week in
                let weekReachedGoal = personalWeeks.contains {
                    $0.goalReached
                        && AppCalendar.calendar.isDate($0.weekStart, inSameDayAs: week[0])
                }

                HStack(spacing: 2) {
                    ForEach(week, id: \.self) { date in
                        ZStack {
                            if isIdent(on: date) {
                                Image("Flash")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.accent)
                            } else if isTarget(on: date) {
                                Image(isMissedTarget(on: date) ? "Flash" : "FlashOutline")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(
                                        isMissedTarget(on: date) ? .red.opacity(0.5) : .accent)
                            } else {
                                Text(String(AppCalendar.calendar.component(.day, from: date)))
                                    .monospacedDigit()
                                    .opacity(
                                        AppCalendar.calendar.isDate(
                                            date, equalTo: month, toGranularity: .month)
                                            ? 1 : 0.2
                                    )
                                    .foregroundStyle(.primary)
                            }

                            if AppCalendar.calendar.isDate(date, inSameDayAs: referenceDate) {
                                Circle()
                                    .stroke(.accent.opacity(0.5), lineWidth: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: dayHeight)
                    }
                }
                .background {
                    if weekReachedGoal {
                        RoundedRectangle(cornerRadius: dayHeight / 2, style: .continuous)
                            .fill(.accent.opacity(0.15))
                            .padding(.vertical, -2)
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

    var calendarWeeks: [[Date]] {
        AppCalendar.weekStartsInMonth(containing: month)
            .map { AppCalendar.datesInWeek(containing: $0) }
    }
}

#Preview("March 2026 · Six weeks") {
    LastMonthView(
        month: PersonalWeek.templateMonth,
        personalWeeks: PersonalWeek.templateWeeks
    )
    .padding()
}

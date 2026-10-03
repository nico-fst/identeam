import SwiftUI

struct MyMonthWidget: View {
    let month: Date
    let personalWeeks: [PersonalWeek]

    var allIdents: [Date] {
        personalWeeks.flatMap(\.identDates)
    }

    var body: some View {
        Section {
            VStack {
                HStack {
                    ForEach(AppCalendar.datesInWeek(containing: month), id: \.self) { date in
                        Text(AppCalendar.weekdayString(date))
                            .bold()
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background {
                                Circle().fill(.secondary.opacity(0.12))
                                    .scaleEffect(0.8)
                            }
                    }
                }
                .padding(.bottom, 10)

                ForEach(calendarWeeks, id: \.self) { week in
                    let weekReachedGoal = personalWeeks.contains(where: { personalWeek in
                        personalWeek.goalReached
                            && AppCalendar.calendar.isDate(
                                personalWeek.weekStart,
                                inSameDayAs: week[0]
                            )
                    })

                    ZStack {
                        if weekReachedGoal {
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .fill(.accent.opacity(0.15))
                                .padding(.vertical, -2)  // making rectangle higher
                        }

                        VStack {
                            HStack {
                                ForEach(week, id: \.self) { date in
                                    ZStack {
                                        if isIdent(on: date) {
                                            Image("Flash")
                                                .renderingMode(.template)
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundStyle(.accent)
                                                .frame(maxWidth: .infinity, maxHeight: 32)
                                        } else {
                                            Text(
                                                String(
                                                    AppCalendar.calendar.component(.day, from: date)
                                                )
                                            )
                                            .monospacedDigit()
                                            .opacity(
                                                AppCalendar.calendar.isDate(
                                                    date, equalTo: month, toGranularity: .month)
                                                    ? 1 : 0.2
                                            )
                                            .frame(maxWidth: .infinity, minHeight: 32)
                                            .foregroundStyle(
                                                isMissedTarget(on: date) && !weekReachedGoal
                                                    ? .red : .primary)
                                        }

                                        if AppCalendar.calendar.isDate(
                                            date,
                                            inSameDayAs: Date()
                                        ) {
                                            Circle()
                                                .stroke(.accent.opacity(0.5), lineWidth: 2)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Month Overview")
        }
    }

    private func isIdent(on date: Date) -> Bool {
        allIdents.contains {
            AppCalendar.calendar.isDate($0, inSameDayAs: date)
        }
    }

    private func isMissedTarget(on date: Date) -> Bool {
        !isIdent(on: date)
            && personalWeeks.contains { week in
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
    List {
        MyMonthWidget(
            month: PersonalWeek.templateMonth,
            personalWeeks: PersonalWeek.templateWeeks
        )
    }
    .listStyle(.insetGrouped)
}

import SwiftUI

struct TeamWeekModePicker: View {
    @Binding var detailed: Bool
    let dark: Bool
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 4) {
            ForEach([false, true], id: \.self) { value in
                Button {
                    withAnimation(.smooth(duration: 0.3)) { detailed = value }
                } label: {
                    Text(value ? "Combined" : "Smart")
                        .font(TeamWeekStyle.font(14, heavy: true))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(
                            (dark ? AppColor.Palette.cream : AppColor.Palette.ink)
                                .opacity(detailed == value ? 1 : 0.55)
                        )
                        .background {
                            if detailed == value {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.white.opacity(dark ? 0.14 : 0.65))
                                    .matchedGeometryEffect(id: "selected", in: selection)
                                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            (dark ? Color.black : AppColor.Palette.ink).opacity(0.04), in: .rect(cornerRadius: 18)
        )
    }
}

struct TeamWeekCalendar: View {
    @Binding var selection: Date
    let onSelect: () -> Void
    @State private var month: Date

    init(selection: Binding<Date>, onSelect: @escaping () -> Void) {
        _selection = selection
        self.onSelect = onSelect
        _month = State(initialValue: AppCalendar.startOfMonth(containing: selection.wrappedValue))
    }

    private var days: [Date] {
        AppCalendar.weekStartsInMonth(containing: month).flatMap {
            AppCalendar.datesInWeek(containing: $0)
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = AppCalendar.calendar.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(monthTitle).font(TeamWeekStyle.font(17, heavy: true))
                Spacer()
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left").frame(width: 36, height: 36)
                }
                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 36)
                }
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4
            ) {
                ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { day in
                    Text(day).font(TeamWeekStyle.font(12)).foregroundStyle(AppColor.muted)
                }
                ForEach(days, id: \.self) { day in
                    let isToday = AppCalendar.calendar.isDateInToday(day)
                    let selected =
                        AppCalendar.startOfWeek(containing: day)
                        == AppCalendar.startOfWeek(containing: selection)
                    Button {
                        selection = AppCalendar.startOfWeek(containing: day)
                        onSelect()
                    } label: {
                        Text("\(AppCalendar.calendar.component(.day, from: day))")
                            .font(TeamWeekStyle.font(16))
                            .frame(width: 34, height: 34)
                            .background {
                                if selected && !isToday {
                                    Circle().fill(AppColor.accent.opacity(0.35))
                                }
                            }
                            .overlay {
                                if isToday {
                                    Circle().strokeBorder(AppColor.accent, lineWidth: 2.5)
                                }
                            }
                            .opacity(
                                selected || isToday
                                    || AppCalendar.calendar.isDate(
                                        day, equalTo: month, toGranularity: .month)
                                    ? 1 : 0.35
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColor.text)
        .onChange(of: selection) { month = AppCalendar.startOfMonth(containing: selection) }
    }

    private func moveMonth(by offset: Int) {
        month = AppCalendar.calendar.date(byAdding: .month, value: offset, to: month)!
    }
}

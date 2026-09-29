import SwiftUI

struct CurrentWeekWidget: View {
    let teamWeek: TeamWeek
    let onSelectIdent: (Ident) -> Void
    
    @State private var showSettings = false
    
    @AppStorage private var showIdentImages: Bool

    init(teamWeek: TeamWeek, onSelectIdent: @escaping (Ident) -> Void) {
        self.teamWeek = teamWeek
        self.onSelectIdent = onSelectIdent
        _showIdentImages = AppStorage(wrappedValue: true, "week.\(teamWeek.slug).weekgrid.showIdentImages")
    }

    var body: some View {
        Section {
            grid
        } header: {
            HStack {
                Text("Current Week")
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        } footer: {
//            Text("Your team collected \(teamWeek.identSum) / \(teamWeek.targetSum) Idents in total")
        }
        .sheet(isPresented: $showSettings) {
            settings
        }
    }

    private let columns = Array(
        repeating: GridItem(
            .flexible(minimum: 0),
            spacing: 0
        ),
        count: 8
    )

    private func cell<Content: View>(
        isHeader: Bool = false,
        isToday: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .font(isHeader && isToday ? .headline : .body)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                if isHeader {
                    if isToday {
                        Circle().fill(.accent.opacity(0.25))
                            .scaleEffect(0.8)
                    } else {
                        Circle().fill(Color.secondary.opacity(0.12))
                            .scaleEffect(0.8)
                    }
                }
            }
            .padding(2)
    }

    private func dayCell(_ day: MemberDay<Ident>, member: TeamMember) -> some View {
        cell {
            if let ident = day.ident {
                Button {
                    onSelectIdent(ident)
                } label: {
                    VStack(spacing: 4) {
                        IdentThumbnailView(
                            image: RemoteImageReference(item: ident.image),
                            avatar: RemoteImageReference(item: member.user.avatar),
                            showImage: showIdentImages
                        )
                        .frame(height: 55)
                    }
                }
                .buttonStyle(.plain)
            } else if day.isTargetDay {
                Image(systemName: "calendar.badge.clock")
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Nothing planned")
            }
        }
    }

    private var grid: some View {
        let referenceDate = Date()
        let members = teamWeek.members.sorted {
            $0.user.username.lowercased() < $1.user.username.lowercased()
        }
        let dates = AppCalendar.datesInWeek(containing: teamWeek.weekStart)
        
        return LazyVGrid(columns: columns, spacing: 0) {
            // header
            Group {
                cell() {
                    HStack(spacing: 2) {
                        Text(String(teamWeek.teamStreak))
                        
                        if teamWeek.teamStreak > 0 {
                            Image(systemName: "flame.fill")
                        } else {
                            Image(systemName: "snowflake")
                        }
                    }
                    .foregroundStyle(teamWeek.teamStreak > 0
                                     ? .orange
                                     : .blue
                    )
                    .bold()
                }
                ForEach(dates, id: \.self) { date in
                    cell(
                        isHeader: true,
                        isToday: AppCalendar.calendar.isDate(date, inSameDayAs: referenceDate)
                    ) {
                        Text(AppCalendar.weekdayString(date))
                    }
                }
            }

            // row per member
            ForEach(members, id: \.id) { member in
                cell() {
                    VStack(spacing: 2) {
                        FilledUserAvatar(
                            image: RemoteImageReference(item: member.user.avatar),
                            progress: member.targetDays.count > 0
                                ? Double(member.idents.count) / Double(member.targetDays.count)
                                : 0
                        )
                        Text("\(member.idents.count) / \(member.targetDays.count)")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.secondary)
                    }
                    .padding(5)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous) // squircle by .continuous
                            .fill(.secondary.opacity(0.12))
                    }
                }
                
                ForEach(dates, id: \.self) { date in
                    dayCell(
                        MemberDay(date: date, idents: member.idents, time: \.time, targetDays: member.targetDays),
                        member: member
                    )
                }
            }
        }
    }

    private var settings: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Idents show images", isOn: $showIdentImages)
                } footer: {
                    Text("Controls wether ident are filled with user's image or just a color.")
                }
            }
            .padding()
            .navigationTitle("Grid Settings")
        }
        .presentationDetents([.medium])
    }
}

private nonisolated struct MemberDay<IdentValue>: Identifiable {
    let date: Date
    let ident: IdentValue?
    let isTargetDay: Bool

    var id: Date { date }

    init(date: Date, idents: [IdentValue], time: KeyPath<IdentValue, Date>, targetDays: [Date]) {
        let calendar = AppCalendar.calendar
        self.date = date
        self.ident = idents
            .filter { calendar.isDate($0[keyPath: time], inSameDayAs: date) }
            .max { $0[keyPath: time] < $1[keyPath: time] }
        self.isTargetDay = targetDays.contains {
            calendar.isDate($0, inSameDayAs: date)
        }
    }
}

#Preview("List(CurrentWeekWidget)") {
    List {
        CurrentWeekWidget(
            teamWeek: TeamWeek.templateKanten
        ) { ident in
            print("Selected ident:", ident.id)
        }
    }
    .listStyle(.insetGrouped)
}

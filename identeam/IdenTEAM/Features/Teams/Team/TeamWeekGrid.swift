import SwiftUI

struct TeamWeekGrid: View {
    let week: TeamWeekPresentation
    let members: [TeamMember]
    let onSelectIdent: (String) -> Void
    @AppStorage private var showIdentImages: Bool
    @State private var detailed = false
    @State private var explanationMarkID: String?
    @State private var barProgress: Double = 0

    init(
        slug: String, week: TeamWeekPresentation, members: [TeamMember],
        initiallyDetailed: Bool = false,
        onSelectIdent: @escaping (String) -> Void
    ) {
        _showIdentImages = AppStorage(
            wrappedValue: true, TeamWeekImageSettings.key(for: slug))
        self.week = week
        self.members = members
        self.onSelectIdent = onSelectIdent
        _detailed = State(initialValue: initiallyDetailed)
    }

    private let legendMarkerSize: CGFloat = 10

    private var foreground: Color { week.darkWeek ? AppColor.Palette.cream : AppColor.Palette.ink }
    private var transitionAnimation: Animation {
        .spring(duration: 0.55, bounce: 0.12)
    }

    var body: some View {
        VStack(spacing: 12) {
            TeamWeekModePicker(detailed: $detailed, dark: week.darkWeek)

            GeometryReader { geometry in
                scene(
                    TeamWeekGeometry(
                        width: geometry.size.width, memberCount: week.members.count,
                        detailed: detailed))
            }
            .frame(
                height: TeamWeekGeometry(
                    width: 320, memberCount: week.members.count, detailed: detailed
                ).height)

            if !detailed { footer.transition(.opacity) }
        }
        .padding(14)
        .modifier(AppGlass(dark: week.darkWeek))
        .animation(transitionAnimation, value: detailed)
        .onAppear { fillBar() }
        .onChange(of: detailed) {
            explanationMarkID = nil
            if detailed { barProgress = 0 } else { fillBar() }
        }
        .onChange(of: week.personalProgress) { if !detailed { fillBar() } }
    }

    private func scene(_ layout: TeamWeekGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            if let today = week.todayIndex() {
                let rect = layout.todayFrame(today)
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColor.accent.opacity(week.darkWeek ? 0.22 : 0.10))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
            ForEach(Array(week.dates.enumerated()), id: \.offset) { index, date in
                VStack(spacing: 2) {
                    Text(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][index])
                        .font(TeamWeekStyle.font(12, heavy: true))
                    Text("\(AppCalendar.calendar.component(.day, from: date))")
                        .font(TeamWeekStyle.font(11))
                        .opacity(0.6)
                }
                .frame(width: layout.dayWidth, height: 34)
                .position(x: layout.dayX(index), y: 17)
            }
            ForEach(0..<7, id: \.self) { day in
                if detailed {
                    ForEach(Array(week.members.enumerated()), id: \.element.id) { index, member in
                        if week.marks(on: day, memberID: member.id).isEmpty {
                            emptyMark.position(x: layout.dayX(day), y: layout.rowY(index))
                        }
                    }
                } else if week.marks(on: day).isEmpty {
                    emptyMark.position(x: layout.dayX(day), y: layout.dayHeaderHeight + 30)
                }
            }
            // One retained view per Ident/plan. Only its coordinates and depth change.
            ZStack(alignment: .topLeading) {
                ForEach(week.marks) { mark in
                    let row = week.members.firstIndex { $0.id == mark.memberID } ?? 0
                    let stack = week.marks(on: mark.day, memberID: detailed ? mark.memberID : nil)
                    let index = stack.firstIndex { $0.id == mark.id } ?? 0
                    markView(mark)
                        .frame(width: 54, height: 54)
                        .position(
                            layout.markPosition(
                                day: mark.day, member: row, stack: index, count: stack.count)
                        )
                        .zIndex(Double(stack.count - index))
                }
            }
            .compositingGroup()
            ForEach(Array(week.members.enumerated()), id: \.element.id) { index, member in
                person(member)
                    .frame(width: 48)
                    .position(x: detailed ? 24 : -40, y: layout.rowY(index))
                    .opacity(detailed ? 1 : 0)
                    .animation(rowAnimation(index), value: detailed)
                TeamWeekProgressFlash(
                    completed: member.completed, target: member.target,
                    color: TeamWeekStyle.color(for: member.id, in: week),
                    dark: week.darkWeek, active: detailed
                )
                .frame(width: 82, height: 82)
                .position(
                    x: detailed ? layout.width - layout.summaryWidth / 2 : layout.width + 50,
                    y: layout.rowY(index)
                )
                .opacity(detailed ? 1 : 0)
                .animation(rowAnimation(index), value: detailed)
            }
        }
        .foregroundStyle(foreground)
        .contentShape(Rectangle())
        .onTapGesture { if !detailed { detailed = true } }
        .clipped()
    }

    private func rowAnimation(_ row: Int) -> Animation {
        let order = detailed ? row : week.members.count - row - 1
        return .spring(duration: 0.45, bounce: 0.1).delay(Double(order) * 0.075)
    }

    private var emptyMark: some View {
        Text("–").font(TeamWeekStyle.font(18)).foregroundStyle(foreground.opacity(0.30))
    }

    private func markView(_ mark: TeamWeekPresentation.Mark) -> some View {
        let color = TeamWeekStyle.color(for: mark.memberID, in: week)
        return ZStack {
            // Erase both the halo and the interior from earlier layers. This keeps outlined
            // plans opaque to other Idents while preserving the real glass underneath.
            FlashShape().fill(.black).blendMode(.destinationOut)
            FlashShape().stroke(.black, lineWidth: 4).blendMode(.destinationOut)
            if mark.kind == .planned {
                FlashShape().stroke(color, lineWidth: 1.8)
            } else {
                FlashShape().fill(color.opacity(mark.kind == .missed ? 0.22 : 1))
                if let id = mark.thumbnailIdentID(showImages: showIdentImages),
                    let ident = members.first(where: { $0.user.userID == mark.memberID })?
                        .idents.first(where: { TeamWeekPresentation.identID($0) == id })
                {
                    IdentImageView(image: RemoteImageReference(item: ident.image))
                        .clipShape(FlashShape())
                }
            }
        }
        .contentShape(FlashShape())
        .onTapGesture { select(mark) }
        .popover(
            isPresented: Binding(
                get: { explanationMarkID == mark.id },
                set: { if !$0 { explanationMarkID = nil } }
            ), attachmentAnchor: .rect(.bounds), arrowEdge: .top
        ) {
            TeamWeekLegend().padding(24).presentationCompactAdaptation(.popover)
        }
    }

    private func select(_ mark: TeamWeekPresentation.Mark) {
        guard detailed else {
            detailed = true
            return
        }

        switch mark.interaction {
        case .image(let id): onSelectIdent(id)
        case .explanation: explanationMarkID = mark.id
        }
    }

    private func person(_ member: TeamWeekPresentation.Member) -> some View {
        VStack(spacing: 3) {
            if let source = members.first(where: { $0.user.userID == member.id }) {
                UserAvatarView(image: RemoteImageReference(item: source.user.avatar)).frame(
                    width: 31, height: 31)
            } else {
                Text(String(member.name.prefix(1))).font(TeamWeekStyle.font(17, heavy: true))
                    .frame(width: 31, height: 31)
                    .background(
                        TeamWeekStyle.color(for: member.id, in: week).opacity(0.22), in: .circle)
            }
            Text(member.id == week.currentUserID ? "Du" : member.name)
                .font(TeamWeekStyle.font(10, heavy: true)).lineLimit(1).minimumScaleFactor(0.65)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            progress.frame(width: 64)
            names
        }
        .foregroundStyle(foreground)
    }

    private var names: some View {
        HStack(spacing: 9) {
            ForEach(week.legendMembers) { member in
                HStack(spacing: 4) {
                    if member.id != week.currentUserID {
                        Circle().fill(TeamWeekStyle.color(for: member.id, in: week)).frame(
                            width: legendMarkerSize, height: legendMarkerSize)
                    }
                    Text(
                        member.id == week.currentUserID
                            ? "Du (\(member.completed)/\(member.target))" : member.name
                    )
                    .lineLimit(1).minimumScaleFactor(0.7)
                }.font(TeamWeekStyle.font(11, heavy: true))
            }
        }
    }

    private var progress: some View {
        GeometryReader { geometry in
            Capsule().fill(foreground.opacity(0.10))
            Capsule().fill(TeamWeekStyle.color(for: week.currentUserID, in: week))
                .frame(width: geometry.size.width * barProgress)
        }
        .frame(height: legendMarkerSize)
    }

    private func fillBar() {
        withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
            barProgress = week.personalProgress
        }
    }

}

struct TeamWeekLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ident-Arten").font(TeamWeekStyle.font(19, heavy: true))
            row("Erledigt · zählt zum Fortschritt", kind: .completed)
            row("Geplant · dein nächster Schritt", kind: .planned)
            row("Verpasst · zählt nicht zum Fortschritt", kind: .missed)
        }.font(TeamWeekStyle.font(14))
    }

    private func row(_ title: String, kind: TeamWeekPresentation.MarkKind) -> some View {
        HStack {
            Group {
                if kind == .planned {
                    FlashShape().stroke(.primary, lineWidth: 1.6)
                } else {
                    FlashShape().fill(.primary.opacity(kind == .missed ? 0.22 : 1))
                }
            }.frame(width: 30, height: 30)
            Text(title)
        }
    }
}

import SwiftData
import SwiftUI

struct IdentDetailView: View {
    let selection: IdentDetailPresentation.Selection
    let presentation: IdentDetailPresentation
    let viewport: IdentDetailViewport

    @State private var selectedProfileUser: User?
    @State private var isSending = false
    @State private var composerHeight: CGFloat = 76
    @State private var panelDrag: CGFloat = 0
    @State private var flashDrag: CGSize = .zero
    @State private var flashPressed = false

    @FocusState private var composerFocused: Bool

    @AppStorage("userID") private var userID = ""

    @Query private var users: [User]

    @EnvironmentObject private var vm: AppVM
    @EnvironmentObject private var teamsVM: TeamsVM
    @EnvironmentObject private var teamVM: TeamWeekVM
    @Environment(\.modelContext) private var ctx

    private var ident: Ident { teamVM.selectedIdent ?? selection.ident }
    private var color: Color { selection.source.color }
    private var phase: IdentDetailPresentation.Phase { presentation.phase }
    private var comments: [Comment] { ident.comments.sorted { $0.time < $1.time } }
    private var canSend: Bool {
        !isSending && !teamVM.commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            let size = viewport.size
            let layout = IdentDetailLayout(
                size: size, safeArea: viewport.safeArea, composerHeight: composerHeight)
            let frame = layout.flashFrame(
                phase: phase, source: selection.source.frame,
                overlayOrigin: geometry.frame(in: .global).origin)
            ZStack(alignment: .topLeading) {
                backdrop
                IdentCommentsView(
                    comments: comments, currentUserID: userID, color: color, drag: $panelDrag,
                    onSelectUser: showProfile,
                    onDelete: deleteComment, onDismiss: dismiss
                )
                .frame(width: layout.comments.width, height: layout.comments.height)
                .position(x: layout.comments.midX, y: layout.comments.midY)
                .offset(y: phase >= .smallDot ? panelDrag : size.height)
                .opacity(phase >= .smallDot ? 1 : 0)
                .allowsHitTesting(phase >= .smallDot && !presentation.isClosing)
                .zIndex(1)

                flash(frame: frame).zIndex(2)
                IdentThoughtView(
                    author: selection.author, date: ident.time, text: ident.userText,
                    size: size, top: viewport.safeArea.top + 4,
                    flash: layout.flash,
                    phase: phase, isClosing: presentation.isClosing, onSelectUser: showProfile
                )
                .zIndex(3)
                Color.black.opacity(composerFocused ? 0.18 : 0)
                    .contentShape(Rectangle()).onTapGesture { composerFocused = false }
                    .allowsHitTesting(composerFocused)
                    .zIndex(4)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .ignoresSafeArea()
            .overlay(alignment: .topLeading) {
                Color.clear
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        composer
                            .onGeometryChange(for: CGFloat.self) {
                                $0.size.height
                            } action: {
                                composerHeight = $0
                            }
                            .modifier(
                                IdentPanelDrag(
                                    offset: $panelDrag, canStart: true,
                                    onDismiss: dismiss)
                            )
                            .padding(.horizontal, 12).padding(.bottom, 8)
                            .offset(y: phase >= .smallDot ? panelDrag : size.height)
                            .opacity(phase >= .smallDot ? 1 : 0)
                            .allowsHitTesting(phase >= .smallDot && !presentation.isClosing)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .leading, .trailing])
        .task { await presentation.animateIn() }
        .sheet(item: $selectedProfileUser) { user in
            NavigationStack {
                TeamMemberProfileView(
                    user: user, slug: selection.slug,
                    month: AppCalendar.startOfMonth(containing: ident.time), viewerID: userID,
                    referenceDate: .now,
                    showsMonth: AppCalendar.startOfWeek(containing: ident.time)
                        <= AppCalendar.startOfWeek(containing: .now))
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            color
            LinearGradient(
                colors: [.white.opacity(0.08), .clear, .black.opacity(0.14)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .opacity(phase >= .hero ? 0.90 : phase == .lifted ? 0.10 : 0)
        .contentShape(Rectangle()).onTapGesture { dismiss() }
    }

    private func flash(frame: CGRect) -> some View {
        ImageFlash(
            image: selection.source.showsImage || phase >= .hero
                ? RemoteImageReference(item: ident.image) : nil, color: color, usesGlassBorder: true
        )
        .frame(width: frame.width, height: frame.height)
        .scaleEffect(phase == .source && !presentation.isClosing ? 0.82 : flashPressed ? 0.95 : 1)
        .animation(.spring(duration: 0.24, bounce: 0.24), value: flashPressed)
        .shadow(color: .black.opacity(phase >= .hero ? 0.42 : 0), radius: 34, y: 22)
        .shadow(color: .black.opacity(phase >= .hero ? 0.20 : 0), radius: 9, y: 5)
        .modifier(
            IdentFlashHover(isActive: phase >= .thought && !flashPressed && !presentation.isClosing)
        )
        .contentShape(FlashShape())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    flashPressed = true
                    flashDrag = value.translation
                }
                .onEnded { value in
                    flashPressed = false
                    if IdentDetailGesture.dismissFlash(translation: value.translation) {
                        dismiss()
                    } else {
                        withAnimation(.spring(duration: 0.3, bounce: 0.25)) { flashDrag = .zero }
                    }
                }
        )
        .position(x: frame.midX + flashDrag.width, y: frame.midY + flashDrag.height)
        .allowsHitTesting(phase >= .hero && !presentation.isClosing)
    }

    private var composer: some View {
        IdentCommentComposer(
            text: $teamVM.commentInput, error: teamVM.commentError,
            user: users.first { $0.userID == userID }, color: color,
            isSending: isSending, canSend: canSend, focus: $composerFocused
        ) {
            guard canSend else { return }
            isSending = true
            Task {
                await teamVM.tryCommenting(slug: selection.slug, vm: vm, ctx: ctx, teamsVM: teamsVM)
                isSending = false
            }
        }
    }

    private func dismiss() {
        composerFocused = false
        Task { await presentation.dismiss { flashDrag = .zero } }
    }

    private func deleteComment(_ id: Int) {
        Task {
            await teamVM.tryDeletingComment(
                commentID: id, slug: selection.slug,
                vm: vm, ctx: ctx, teamsVM: teamsVM)
        }
    }

    private func showProfile(_ user: User) {
        composerFocused = false
        selectedProfileUser = user
    }
}

/// Idle motion belongs only to the Flash; dragging takes over its position immediately.
private struct IdentFlashHover: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isActive)) { timeline in
            content.offset(
                y: isActive ? sin(timeline.date.timeIntervalSinceReferenceDate * .pi / 2.4) * 7 : 0)
        }
    }
}

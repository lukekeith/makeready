//
//  OverlayManager.swift
//  MakeReady
//
//  Centralized service for managing overlays with explicit z-index control.
//  Overlays are rendered at the root level (MainView) in priority order.
//

import SwiftUI

// MARK: - Environment Keys for Modal/Menu Context

/// Environment key to detect if the modal container provides its own drag indicator
/// Used by PageTitle to avoid rendering duplicate drag indicators
/// When true, PageTitle should not render its own drag indicator
private struct ModalProvidesDragIndicatorKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

/// Environment key for dismissing the containing menu/modal
/// Content can call this action to trigger the wrapper's animated dismissal
private struct DismissOverlayThenActionKey: EnvironmentKey {
    static let defaultValue: ((@escaping () -> Void) -> Void)? = nil
}

private struct DismissOverlayActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

/// Environment key indicating the view is the root of a modal presentation
/// Used by PageTitle to auto-resolve left icon: xmark for modal root, chevron.left for pushed
private struct IsModalRootKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Indicates that the containing modal provides a drag indicator for swipe-to-dismiss
    /// PageTitle should not render its own drag indicator when this is true
    var modalProvidesDragIndicator: Bool {
        get { self[ModalProvidesDragIndicatorKey.self] }
        set { self[ModalProvidesDragIndicatorKey.self] = newValue }
    }

    /// Action to dismiss the containing overlay with animation
    /// Used by menu/modal content to trigger parent's animated dismissal
    var dismissOverlay: (() -> Void)? {
        get { self[DismissOverlayActionKey.self] }
        set { self[DismissOverlayActionKey.self] = newValue }
    }

    /// Like `dismissOverlay`, but runs the supplied completion once the
    /// overlay has actually left the stack (its exit animation finished).
    /// Phase 3.2 — content uses this for dismiss-then-present choreography
    /// instead of wall-clock asyncAfter waits.
    var dismissOverlayThen: ((@escaping () -> Void) -> Void)? {
        get { self[DismissOverlayThenActionKey.self] }
        set { self[DismissOverlayThenActionKey.self] = newValue }
    }

    /// Indicates this view is the root of a modal (fullScreenCover or ManagedModal)
    /// PageTitle uses this to auto-resolve: xmark for modal root, chevron.left for pushed
    var isModalRoot: Bool {
        get { self[IsModalRootKey.self] }
        set { self[IsModalRootKey.self] = newValue }
    }
}

// MARK: - Modal/Overlay IDs

// The stringly-typed `enum OverlayID` was removed in Phase 3.6d — `Route`
// (Services/Route.swift) is the typed identity for every overlay surface.
// `Route.id` produces the same strings, and the string-keyed methods below
// remain as the underlying implementation (and for the handful of dynamic
// per-entity ids, e.g. GlobalSearchPage lesson/video modals).
// The retired `backgroundPicker_<blockId>` id is documented in Route.swift.

/// Priority levels for overlays - higher values render on top
enum OverlayPriority: Int, Comparable {
    case modal = 100        // Standard modals (ProgramHomePage, etc.)
    case menu = 200         // Menus (AddMenu, UserMenu, etc.)
    case topLevel = 300     // Always-on-top items (AddActivityMenu, alerts)

    static func < (lhs: OverlayPriority, rhs: OverlayPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A single overlay item with its content and metadata
struct OverlayItem: Identifiable {
    let id: String
    let priority: OverlayPriority
    let content: AnyView
}

/// Centralized manager for all overlays in the app
///
/// Usage:
/// ```swift
/// // In any child view
/// @Environment(OverlayManager.self) var overlayManager
///
/// // Present a modal (with dark background, swipe-to-dismiss, animations)
/// overlayManager.presentModal(id: "myModal", priority: .modal) {
///     MyModalContent()
/// }
///
/// // Present a raw overlay (no chrome, you handle everything)
/// overlayManager.present(id: "myOverlay", priority: .topLevel) {
///     MyOverlayView()
/// }
///
/// // Dismiss an overlay
/// overlayManager.dismiss(id: "myOverlay")
/// ```
@Observable
class OverlayManager {
    private(set) var overlays: [OverlayItem] = []

    /// Animated-dismiss handlers registered by the Managed wrapper views
    /// (modal/menu/page chrome). Lets dismiss(id:then:) trigger the real
    /// exit animation instead of removing instantly.
    @ObservationIgnored private var animatedDismissHandlers: [String: () -> Void] = [:]

    /// Completions waiting for an overlay to actually leave the stack.
    @ObservationIgnored private var dismissCompletions: [String: [() -> Void]] = [:]

    /// Called by the Managed wrapper views so the manager can drive their
    /// exit animation from dismiss(id:then:).
    func registerAnimatedDismiss(id: String, _ handler: @escaping () -> Void) {
        animatedDismissHandlers[id] = handler
    }

    /// Present a modal with full modal chrome (dark background, swipe-to-dismiss, animations)
    /// - Parameters:
    ///   - id: Unique identifier for the modal (used for dismissal)
    ///   - priority: Z-index priority level (default: .modal)
    ///   - dismissOnTapOutside: Whether tapping the dark background dismisses (default: true)
    ///   - showDragIndicator: Whether to show the drag indicator for swipe-to-dismiss (default: true)
    ///   - content: The view to present inside the modal
    func presentModal<V: View>(
        id: String,
        priority: OverlayPriority = .modal,
        dismissOnTapOutside: Bool = true,
        showDragIndicator: Bool = true,
        @ViewBuilder content: () -> V
    ) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let modalContent = content()
        present(id: id, priority: priority) {
            ManagedModalView(
                id: id,
                dismissOnTapOutside: dismissOnTapOutside,
                showDragIndicator: showDragIndicator,
                content: { modalContent }
            )
        }
    }

    /// Present a menu with swipe-to-dismiss, dark background, and unified animations
    /// - Parameters:
    ///   - id: Unique identifier for the menu (used for dismissal)
    ///   - priority: Z-index priority level (default: .menu)
    ///   - showDragIndicator: Whether to show the drag indicator for swipe-to-dismiss (default: true)
    ///   - content: The view to present inside the menu
    func presentMenu<V: View>(
        id: String,
        priority: OverlayPriority = .menu,
        showDragIndicator: Bool = true,
        @ViewBuilder content: () -> V
    ) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let menuContent = content()
        present(id: id, priority: priority) {
            ManagedMenuView(
                id: id,
                showDragIndicator: showDragIndicator,
                content: { menuContent }
            )
        }
    }

    /// Present a page that slides in from the right (push-style navigation)
    /// - Parameters:
    ///   - id: Unique identifier for the page (used for dismissal)
    ///   - priority: Z-index priority level (default: .modal)
    ///   - content: The view to present as a full-screen page
    func presentPage<V: View>(
        id: String,
        priority: OverlayPriority = .modal,
        @ViewBuilder content: () -> V
    ) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let pageContent = content()
        present(id: id, priority: priority) {
            ManagedPageView(
                id: id,
                content: { pageContent }
            )
        }
    }

    /// Present a raw overlay with a given ID and priority (no modal chrome)
    /// Use this for menus, alerts, or custom overlays that handle their own presentation
    /// - Parameters:
    ///   - id: Unique identifier for the overlay (used for dismissal)
    ///   - priority: Z-index priority level
    ///   - content: The view to present as an overlay
    func present<V: View>(id: String, priority: OverlayPriority, @ViewBuilder content: () -> V) {
        // Remove existing overlay with same ID if present (prevents duplicates)
        overlays.removeAll { $0.id == id }

        let item = OverlayItem(
            id: id,
            priority: priority,
            content: AnyView(content())
        )
        overlays.append(item)
        // Sort by priority so lower priority items render first (appear below)
        overlays.sort { $0.priority < $1.priority }
    }

    /// Dismiss an overlay by ID (instant removal — the Managed wrappers
    /// call this at the END of their exit animations)
    /// - Parameter id: The ID of the overlay to dismiss
    func dismiss(id: String) {
        overlays.removeAll { $0.id == id }
        animatedDismissHandlers[id] = nil
        for completion in dismissCompletions.removeValue(forKey: id) ?? [] {
            completion()
        }
    }

    /// Dismiss an overlay with its exit animation, then run `completion`
    /// once it has actually left the overlay stack (Phase 3.2 — replaces
    /// the wall-clock `asyncAfter(0.35)` dismiss-then-present waits).
    /// Runs `completion` immediately if the overlay isn't presented.
    func dismiss(id: String, then completion: @escaping () -> Void) {
        guard isPresented(id: id) else {
            completion()
            return
        }
        dismissCompletions[id, default: []].append(completion)
        if let animated = animatedDismissHandlers[id] {
            animated()  // ends by calling dismiss(id:), which fires completions
        } else {
            dismiss(id: id)
        }
    }

    /// Check if an overlay is currently presented
    /// - Parameter id: The ID to check
    /// - Returns: True if an overlay with the given ID is currently presented
    func isPresented(id: String) -> Bool {
        overlays.contains { $0.id == id }
    }

    /// Get all overlays sorted by priority (for rendering)
    /// Lower priority items are first in the array (rendered below higher priority)
    var sortedOverlays: [OverlayItem] {
        overlays.sorted { $0.priority < $1.priority }
    }
}

// MARK: - Managed Modal View

/// Internal view that provides modal chrome (dark background, slide-up animation, swipe-to-dismiss)
/// for modals presented through OverlayManager.
///
/// Swipe-to-dismiss is now handled at the modal level via the drag indicator.
/// The drag indicator is shown by default and can be disabled via showDragIndicator: false.
/// Content views receive isInsideManagedModal environment value to prevent duplicate drag indicators.
struct ManagedModalView<Content: View>: View {
    @Environment(OverlayManager.self) private var overlayManager

    let id: String
    let dismissOnTapOutside: Bool
    let showDragIndicator: Bool
    let content: () -> Content

    // Animation state
    @State private var offset: CGFloat = Screen.bounds.height
    @State private var overlayOpacity: Double = 0
    @State private var isDismissing = false
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dark overlay background
            Color.black.opacity(overlayOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    if dismissOnTapOutside {
                        dismiss()
                    }
                }

            // Full-screen modal (bottom-aligned)
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    content()
                        .environment(\.modalProvidesDragIndicator, showDragIndicator)
                        .environment(\.isModalRoot, true)
                        .environment(\.dismissOverlay, dismiss)
                        .environment(\.dismissOverlayThen) { completion in overlayManager.dismiss(id: id, then: completion) }
                }
                .frame(maxWidth: .infinity)
                .background(Color.appBackground)
                .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16))
                .overlay(alignment: .top) {
                    // Drag indicator overlaid on content so images extend to the top edge
                    if showDragIndicator {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .overlay {
                                Capsule()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: 34, height: 5)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                    .updating($dragOffset) { value, state, transaction in
                                        // Only allow downward drag, disable animations during drag
                                        if value.translation.height > 0 {
                                            transaction.animation = nil
                                            state = value.translation.height
                                        }
                                    }
                                    .onEnded { value in
                                        if value.translation.height > 80 {
                                            // Transfer drag position to offset before dismissing
                                            // This prevents "jump back" when GestureState resets
                                            offset += value.translation.height
                                            dismiss()
                                        }
                                        // GestureState automatically resets to 0 with spring animation
                                    }
                            )
                    }
                }
                .compositingGroup()  // Flatten into single render layer before offset
                .offset(y: offset + dragOffset)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            overlayManager.registerAnimatedDismiss(id: id) { dismiss() }
            // Defer animation by one run loop iteration so the content layout
            // pass completes first. Without this, text elements (titles, descriptions)
            // may appear at their final position instead of sliding up with the modal.
            // The view is invisible during this frame (off-screen offset + zero opacity).
            DispatchQueue.main.async {
                ModalAnimations.animateAppear(offset: $offset, overlayOpacity: $overlayOpacity)
            }
        }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true

        // Use single animation block to prevent curve conflicts
        ModalAnimations.animateDismiss(
            offset: $offset,
            overlayOpacity: $overlayOpacity,
            screenHeight: Screen.bounds.height
        ) {
            overlayManager.dismiss(id: id)
        }
    }
}

// MARK: - Managed Page View

/// Internal view that provides push-style page navigation (slide from right)
/// Full-screen with no dark background overlay - replaces the current view visually.
struct ManagedPageView<Content: View>: View {
    @Environment(OverlayManager.self) private var overlayManager

    let id: String
    let content: () -> Content

    @State private var offset: CGFloat = Screen.bounds.width
    @State private var isDismissing = false
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Dimmed background visible during edge-swipe
            Color.black.opacity(dimOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
                .environment(\.pageDismiss, dismiss)
                .offset(x: max(0, offset + dragOffset))
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .global)
                        .updating($dragOffset) { value, state, transaction in
                            // Only allow right-swipe starting from left edge
                            if value.startLocation.x < 40 && value.translation.width > 0 {
                                transaction.animation = nil
                                state = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.startLocation.x < 40 && value.translation.width > 80 {
                                offset += value.translation.width
                                dismiss()
                            }
                        }
                )
        }
        .onAppear {
            overlayManager.registerAnimatedDismiss(id: id) { dismiss() }
            DispatchQueue.main.async {
                withAnimation(Motion.pagePush) {
                    offset = 0
                }
            }
        }
    }

    private var dimOpacity: Double {
        let totalOffset = max(0, offset + dragOffset)
        let progress = 1.0 - (totalOffset / Screen.bounds.width)
        return 0.3 * progress
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true

        // Removal is tied to the actual slide-out animation (Phase 3.2)
        // instead of an asyncAfter mirroring its duration.
        withAnimation(Motion.pageDismiss) {
            offset = Screen.bounds.width
        } completion: {
            overlayManager.dismiss(id: id)
        }
    }
}

// MARK: - Page Dismiss Environment Key

/// Environment key so pages can trigger an animated slide-out dismiss
private struct PageDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var pageDismiss: (() -> Void)? {
        get { self[PageDismissKey.self] }
        set { self[PageDismissKey.self] = newValue }
    }
}

// MARK: - Managed Menu View

/// Internal view that provides menu chrome (dark background, slide-up animation, swipe-to-dismiss)
/// for menus presented through OverlayManager.
///
/// Unlike ManagedModalView, menus size to fit their content rather than filling the screen.
/// Swipe-to-dismiss uses the same @GestureState pattern for jitter-free dragging.
struct ManagedMenuView<Content: View>: View {
    @Environment(OverlayManager.self) private var overlayManager

    let id: String
    let showDragIndicator: Bool
    let content: () -> Content

    // Animation state
    @State private var offset: CGFloat = Screen.bounds.height
    @State private var overlayOpacity: Double = 0
    @State private var isDismissing = false
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dark overlay background - tap to dismiss
            Color.black.opacity(overlayOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Menu content (sizes to fit, bottom-aligned)
            VStack(spacing: 0) {
                // Drag indicator for swipe-to-dismiss (Apple standard: 34×5px)
                if showDragIndicator {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 24)
                        .overlay {
                            Capsule()
                                .fill(Color(UIColor.tertiaryLabel))
                                .frame(width: 34, height: 5)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                .updating($dragOffset) { value, state, transaction in
                                    // Only allow downward drag, disable animations during drag
                                    if value.translation.height > 0 {
                                        transaction.animation = nil
                                        state = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > 80 {
                                        // Transfer drag position to offset before dismissing
                                        // This prevents "jump back" when GestureState resets
                                        offset += value.translation.height
                                        dismiss()
                                    }
                                    // GestureState automatically resets to 0 with spring animation
                                }
                        )
                }

                content()
                    .environment(\.modalProvidesDragIndicator, showDragIndicator)
                    .environment(\.dismissOverlay, dismiss)
                    .environment(\.dismissOverlayThen) { completion in overlayManager.dismiss(id: id, then: completion) }
            }
            .frame(maxWidth: .infinity)
            .background(Color(hex: "#111215"))
            .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16))
            .overlay(
                RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16)
                    .stroke(Color(hex: "#242937"), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: -8)
            .compositingGroup()
            .offset(y: offset + dragOffset)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            overlayManager.registerAnimatedDismiss(id: id) { dismiss() }
            // Defer animation by one run loop iteration so the content layout
            // pass completes first. Without this, text elements (titles, descriptions)
            // may appear at their final position instead of sliding up with the menu.
            // The view is invisible during this frame (off-screen offset + zero opacity).
            DispatchQueue.main.async {
                ModalAnimations.animateAppear(offset: $offset, overlayOpacity: $overlayOpacity)
            }
        }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true

        // Use single animation block to prevent curve conflicts
        ModalAnimations.animateDismiss(
            offset: $offset,
            overlayOpacity: $overlayOpacity,
            screenHeight: Screen.bounds.height
        ) {
            overlayManager.dismiss(id: id)
        }
    }
}

// MARK: - Binding Helper

extension OverlayManager {
    /// Create a binding for an overlay's presentation state
    /// Useful when you need to pass a binding to child views
    func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { self.isPresented(id: id) },
            set: { newValue in
                if !newValue {
                    self.dismiss(id: id)
                }
            }
        )
    }
}

// MARK: - Shared Shape

/// Custom shape for rounding specific corners
struct RoundedCornersShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

import SwiftUI
import UIKit

/// ui2-members-browse D1: how a container moves its own tab's stack. UI2Shell injects one per
/// NavigationStack, bound to that stack's tab; the default (previews, capture) does nothing.
struct UI2Navigator {
    var push: (UI2Destination) -> Void = { _ in }
    var pop: () -> Void = {}
    /// ui2-members-edit D13: pop only if `destination` is still on top.
    var popIfTop: (UI2Destination) -> Void = { _ in }
    /// invite-member D11: pop the stack back to `depth` entries.
    var popTo: (Int) -> Void = { _ in }
    /// invite-member D11: the stack's current depth (the entry depth a flow returns to).
    var depth: () -> Int = { 0 }
    /// ui2-groups-browse D8: replace the top entry (first) with a new page (second) — a no-op
    /// unless the first is still on top.
    var replaceTop: (UI2Destination, UI2Destination) -> Void = { _, _ in }
}

private struct UI2NavigatorKey: EnvironmentKey {
    static let defaultValue = UI2Navigator()
}

extension EnvironmentValues {
    var ui2Navigator: UI2Navigator {
        get { self[UI2NavigatorKey.self] }
        set { self[UI2NavigatorKey.self] = newValue }
    }
}

/// members-search-pinned: a section page asks the shell to push its TopNav off screen (Members'
/// active search). Any page saying `true` wins; a page that says nothing leaves the row in place.
struct UI2HidesTopNavKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

/// SPEC D1 / F2: `.toolbar(.hidden, for: .navigationBar)` disables the stack's interactive
/// left-edge pop. Placed in a page of the stack, this re-arms THAT stack's recognizer with a
/// delegate that begins only above the root — scoped to the UI2 stacks, so the 1.0 screens'
/// navigation controllers keep their own behaviour. Re-attached on every appearance, because
/// a push may reset the recognizer's delegate.
struct UI2InteractivePop: UIViewControllerRepresentable {
    /// group-cover-image D26: the page's veto on the edge swipe (nil on a tab's root).
    var backSwipe: UI2BackSwipeGuard?

    func makeCoordinator() -> UI2PopGestureDelegate {
        let delegate = UI2PopGestureDelegate()
        delegate.backSwipe = backSwipe
        return delegate
    }

    func makeUIViewController(context: Context) -> Probe { Probe(popDelegate: context.coordinator) }

    func updateUIViewController(_ uiViewController: Probe, context: Context) {
        context.coordinator.backSwipe = backSwipe
    }

    /// An invisible child controller whose only job is to find its UINavigationController.
    final class Probe: UIViewController {
        private let popDelegate: UI2PopGestureDelegate

        init(popDelegate: UI2PopGestureDelegate) {
            self.popDelegate = popDelegate
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { return nil }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            attach()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            attach()
        }

        private func attach() {
            guard let navigationController else { return }
            popDelegate.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.delegate = popDelegate
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

/// F2: the edge swipe may begin only when the stack has a page above its root.
/// group-cover-image D26: and only when the page on top does not veto it — a vetoed swipe is
/// handed to the page instead (Edit cover asks to discard).
final class UI2PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?
    var backSwipe: UI2BackSwipeGuard?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard (navigationController?.viewControllers.count ?? 0) > 1 else { return false }
        if let backSwipe, backSwipe.blocksBackSwipe() {
            backSwipe.onBlockedBackSwipe()
            return false
        }
        return true
    }
}

/// group-cover-image D26: one per pushed page (`UI2PushedPage`), read from the environment. A page
/// with unsaved work sets `blocksBackSwipe`; the edge swipe then does not pop and
/// `onBlockedBackSwipe` runs instead. The defaults leave the swipe as F2 has it.
@MainActor
final class UI2BackSwipeGuard {
    var blocksBackSwipe: () -> Bool = { false }
    var onBlockedBackSwipe: () -> Void = {}
}

private struct UI2BackSwipeGuardKey: EnvironmentKey {
    static let defaultValue: UI2BackSwipeGuard? = nil
}

extension EnvironmentValues {
    /// group-cover-image D26: the pushed page's back-swipe guard (nil outside a UI2 stack).
    var ui2BackSwipeGuard: UI2BackSwipeGuard? {
        get { self[UI2BackSwipeGuardKey.self] }
        set { self[UI2BackSwipeGuardKey.self] = newValue }
    }
}

/// D1/F2 + group-cover-image D26: a pushed page's chrome — the system bar hidden, the edge pop
/// re-armed, and the page's own back-swipe guard both handed to that pop and put in the environment.
struct UI2PushedPage<Content: View>: View {
    @State private var backSwipe = UI2BackSwipeGuard()
    @ViewBuilder let content: Content

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .background(UI2InteractivePop(backSwipe: backSwipe))
            .environment(\.ui2BackSwipeGuard, backSwipe)
    }
}

extension View {
    /// invite-member Fixes (agent walk round 1, O1): a d2m screen that sizes to its content
    /// (`maxWidth` only) is centred by the NavigationStack; a pushed page fills the screen top-down.
    func ui2PushedPageFill() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Token.layoutBackground.ignoresSafeArea())
    }
}

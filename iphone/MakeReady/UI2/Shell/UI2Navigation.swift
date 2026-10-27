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
    func makeCoordinator() -> UI2PopGestureDelegate { UI2PopGestureDelegate() }

    func makeUIViewController(context: Context) -> Probe { Probe(popDelegate: context.coordinator) }

    func updateUIViewController(_ uiViewController: Probe, context: Context) {}

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
final class UI2PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
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

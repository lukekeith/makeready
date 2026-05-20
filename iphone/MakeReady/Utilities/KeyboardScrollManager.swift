//
//  KeyboardScrollManager.swift
//  MakeReady
//
//  Automatically scrolls any UIScrollView to keep the focused input
//  visible above the keyboard. Activates globally — no per-page setup needed.
//
//  Pages need `.padding(.bottom, KeyboardState.shared.height)` on their
//  ScrollView content so the content size grows enough to allow scrolling.
//
//  Call KeyboardScrollManager.shared.activate() once at app launch.
//

import UIKit
import Combine

final class KeyboardScrollManager {
    static let shared = KeyboardScrollManager()

    private var cancellables: Set<AnyCancellable> = []

    private init() {}

    func activate() {
        guard cancellables.isEmpty else { return }

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardShow(notification)
            }
            .store(in: &cancellables)
    }

    private func handleKeyboardShow(_ notification: Notification) {
        guard
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
            let focusedView = keyWindow.findFirstResponder()
        else { return }

        guard let scrollView = focusedView.findEnclosingScrollView() else { return }

        // Capture references for the delayed block
        let refs = (focusedView: focusedView, scrollView: scrollView,
                    keyboardFrame: keyboardFrame, curveRaw: curveRaw)

        // Wait for SwiftUI to finish its keyboard layout pass (~250ms).
        // This is required because SwiftUI overrides contentOffset during its
        // own animation. After the pass completes, our offset change sticks.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.executeScroll(refs)
        }
    }

    private func executeScroll(_ refs: (focusedView: UIView, scrollView: UIScrollView,
                                        keyboardFrame: CGRect, curveRaw: UInt)) {
        let scrollView = refs.scrollView
        let focusedView = refs.focusedView
        guard focusedView.window != nil else { return }

        let containerFrame = findInputContainer(focusedView: focusedView, in: scrollView)
        let containerInWindow = scrollView.convert(containerFrame, to: nil)
        let keyboardTopInWindow = refs.keyboardFrame.minY
        let padding: CGFloat = 16

        // Already visible
        if containerInWindow.maxY <= keyboardTopInWindow - padding {
            return
        }

        let needed = containerInWindow.maxY - (keyboardTopInWindow - padding)
        var newOffset = scrollView.contentOffset
        newOffset.y += needed

        let curve = UIView.AnimationOptions(rawValue: refs.curveRaw << 16)
        UIView.animate(withDuration: 0.2, delay: 0, options: [curve, .beginFromCurrentState]) {
            scrollView.contentOffset = newOffset
        }
    }

    private func findInputContainer(focusedView: UIView, in scrollView: UIScrollView) -> CGRect {
        var best = focusedView
        var current: UIView? = focusedView.superview

        while let view = current, view !== scrollView {
            let frameInScroll = view.convert(view.bounds, to: scrollView)
            if frameInScroll.height > scrollView.bounds.height * 0.5 {
                break
            }
            best = view
            current = view.superview
        }

        return best.convert(best.bounds, to: scrollView)
    }
}

// MARK: - SwiftUI keyboard padding modifier

import SwiftUI

extension View {
    /// Adds bottom padding that grows to the keyboard height when visible.
    /// Apply to the content inside a ScrollView so there's room to scroll
    /// the focused input above the keyboard.
    func keyboardBottomPadding(_ base: CGFloat = 40) -> some View {
        self.padding(.bottom, KeyboardState.shared.isVisible ? KeyboardState.shared.height : base)
    }
}

// MARK: - UIView helpers

private extension UIView {
    func findEnclosingScrollView() -> UIScrollView? {
        var current: UIView? = superview
        while let view = current {
            if let scrollView = view as? UIScrollView,
               scrollView.isScrollEnabled {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }
}

//
//  CardGestureCoordinator.swift
//  MakeReady
//
//  UIViewRepresentable that coordinates card gestures using UIKit gesture recognizers
//  with proper require(toFail:) chains following Apple's pattern (iOS Mail, Messages).
//
//  Gesture Priority Chain:
//  - TAP fires on single tap
//  - PAN (horizontal) for swipe-to-reveal
//  - SCROLL gets vertical pans when horizontal pan fails
//

import SwiftUI
import UIKit

struct CardGestureCoordinator: UIViewRepresentable {
    // MARK: - Callbacks

    let onTap: (() -> Void)?
    let onSwipeChanged: ((CGFloat, CGFloat) -> Void)?  // offset, velocity
    let onSwipeEnded: ((CGFloat, CGFloat) -> Void)?

    // MARK: - Configuration

    let isSwipeEnabled: Bool
    let swipeState: SwipeState?

    // MARK: - Initializer

    init(
        onTap: (() -> Void)? = nil,
        onSwipeChanged: ((CGFloat, CGFloat) -> Void)? = nil,
        onSwipeEnded: ((CGFloat, CGFloat) -> Void)? = nil,
        isSwipeEnabled: Bool = true,
        swipeState: SwipeState? = nil
    ) {
        self.onTap = onTap
        self.onSwipeChanged = onSwipeChanged
        self.onSwipeEnded = onSwipeEnded
        self.isSwipeEnabled = isSwipeEnabled
        self.swipeState = swipeState
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTap: onTap,
            onSwipeChanged: onSwipeChanged,
            onSwipeEnded: onSwipeEnded,
            isSwipeEnabled: isSwipeEnabled,
            swipeState: swipeState
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let coordinator = context.coordinator

        // Create gestures
        let tapGesture = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )

        let panGesture = UIPanGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )

        // Store references in coordinator
        coordinator.tapGesture = tapGesture
        coordinator.panGesture = panGesture

        // Set delegates
        tapGesture.delegate = coordinator
        panGesture.delegate = coordinator

        // Configure pan to not interfere with other touch handling
        panGesture.cancelsTouchesInView = false
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false

        // Add gestures to view
        view.addGestureRecognizer(tapGesture)
        if isSwipeEnabled {
            view.addGestureRecognizer(panGesture)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update coordinator callbacks when SwiftUI state changes
        context.coordinator.onTap = onTap
        context.coordinator.onSwipeChanged = onSwipeChanged
        context.coordinator.onSwipeEnded = onSwipeEnded
        context.coordinator.isSwipeEnabled = isSwipeEnabled
        context.coordinator.swipeState = swipeState
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        // Callbacks (mutable for updates)
        var onTap: (() -> Void)?
        var onSwipeChanged: ((CGFloat, CGFloat) -> Void)?
        var onSwipeEnded: ((CGFloat, CGFloat) -> Void)?

        // Configuration
        var isSwipeEnabled: Bool
        var swipeState: SwipeState?

        // Gesture references
        weak var tapGesture: UITapGestureRecognizer?
        weak var panGesture: UIPanGestureRecognizer?

        init(
            onTap: (() -> Void)?,
            onSwipeChanged: ((CGFloat, CGFloat) -> Void)?,
            onSwipeEnded: ((CGFloat, CGFloat) -> Void)?,
            isSwipeEnabled: Bool,
            swipeState: SwipeState?
        ) {
            self.onTap = onTap
            self.onSwipeChanged = onSwipeChanged
            self.onSwipeEnded = onSwipeEnded
            self.isSwipeEnabled = isSwipeEnabled
            self.swipeState = swipeState
        }

        // MARK: - Gesture Handlers

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            onTap?()
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }

            let translation = gesture.translation(in: view)
            let velocity = gesture.velocity(in: view)

            guard isSwipeEnabled else { return }

            switch gesture.state {
            case .began:
                swipeState?.isSwiping = true

            case .changed:
                onSwipeChanged?(translation.x, velocity.x)

            case .ended, .cancelled, .failed:
                onSwipeEnded?(translation.x, velocity.x)
                swipeState?.isSwiping = false

            default:
                break
            }
        }

        // MARK: - UIGestureRecognizerDelegate

        /// Direction locking for pan gesture - only begin for horizontal swipes
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer == panGesture,
               let pan = gestureRecognizer as? UIPanGestureRecognizer,
               let view = pan.view {

                let velocity = pan.velocity(in: view)

                // Only horizontal (swipe mode)
                // If vertical velocity > horizontal velocity, fail this gesture
                // This allows the parent ScrollView to handle vertical scrolls
                if abs(velocity.y) > abs(velocity.x) {
                    return false
                }

                return isSwipeEnabled
            }

            return true
        }

        /// Simultaneous recognition rules
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Allow scroll view to work
            if otherGestureRecognizer.view is UIScrollView {
                return true
            }

            // Allow other pan gestures (could be parent scroll view's internal gesture)
            if otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }

            return false
        }
    }
}

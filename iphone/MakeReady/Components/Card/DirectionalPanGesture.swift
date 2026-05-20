//
//  DirectionalPanGesture.swift
//  MakeReady
//
//  UIViewRepresentable wrapper for UIPanGestureRecognizer with velocity-based direction locking
//  Implements iOS native pattern: fails gesture immediately if vertical movement > horizontal
//  This allows parent ScrollView to handle vertical scrolls without gesture conflicts
//

import SwiftUI
import UIKit

struct DirectionalPanGesture: UIViewRepresentable {
    // MARK: - Configuration

    let minimumDistance: CGFloat
    let onChanged: (PanGestureState) -> Void
    let onEnded: (PanGestureState) -> Void

    // MARK: - Initializer

    init(
        minimumDistance: CGFloat = 5,
        onChanged: @escaping (PanGestureState) -> Void,
        onEnded: @escaping (PanGestureState) -> Void
    ) {
        self.minimumDistance = minimumDistance
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(
            minimumDistance: minimumDistance,
            onChanged: onChanged,
            onEnded: onEnded
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.delegate = context.coordinator

        view.addGestureRecognizer(panGesture)
        context.coordinator.panGesture = panGesture

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let minimumDistance: CGFloat
        let onChanged: (PanGestureState) -> Void
        let onEnded: (PanGestureState) -> Void

        weak var panGesture: UIPanGestureRecognizer?

        init(
            minimumDistance: CGFloat,
            onChanged: @escaping (PanGestureState) -> Void,
            onEnded: @escaping (PanGestureState) -> Void
        ) {
            self.minimumDistance = minimumDistance
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        // MARK: - Gesture Handler

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }

            let translation = gesture.translation(in: view)
            let velocity = gesture.velocity(in: view)

            let state = PanGestureState(
                translation: CGSize(width: translation.x, height: translation.y),
                velocity: CGSize(width: velocity.x, height: velocity.y),
                state: gesture.state
            )

            switch gesture.state {
            case .began, .changed:
                onChanged(state)
            case .ended, .cancelled, .failed:
                onEnded(state)
            default:
                break
            }
        }

        // MARK: - UIGestureRecognizerDelegate

        /// CRITICAL: Direction locking happens HERE
        /// This is called BEFORE the gesture begins, allowing us to fail it immediately
        /// if the user is scrolling vertically. This is the iOS native pattern.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = panGesture.view else {
                return true
            }

            let velocity = panGesture.velocity(in: view)

            // VELOCITY-BASED DIRECTION LOCKING (iOS native pattern)
            // If vertical velocity > horizontal velocity, FAIL this gesture immediately
            // This allows the parent ScrollView to handle the vertical scroll
            if abs(velocity.y) > abs(velocity.x) {
                return false  // ← Gesture fails, ScrollView gets the touch
            }

            // Horizontal or ambiguous - allow gesture to begin
            return true
        }

        /// Allow gesture to work simultaneously with scroll views
        /// The velocity check in gestureRecognizerShouldBegin ensures we only claim horizontal gestures
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Allow scroll views to work simultaneously - our velocity check
            // in gestureRecognizerShouldBegin will fail for vertical scrolls anyway
            if otherGestureRecognizer.view is UIScrollView {
                return true
            }
            // Also allow if the other gesture is a pan gesture (could be parent scroll)
            if otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            return false
        }
    }
}

// MARK: - Gesture State

/// State passed to SwiftUI from the pan gesture
struct PanGestureState {
    let translation: CGSize
    let velocity: CGSize
    let state: UIGestureRecognizer.State

    var horizontalDistance: CGFloat {
        abs(translation.width)
    }

    var verticalDistance: CGFloat {
        abs(translation.height)
    }

    var angle: CGFloat {
        abs(atan2(verticalDistance, horizontalDistance) * 180 / .pi)
    }
}

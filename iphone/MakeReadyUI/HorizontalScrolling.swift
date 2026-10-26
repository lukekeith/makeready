//
//  HorizontalScrolling.swift
//  MakeReadyUI — the UI 2.0 module
//
//  The ONE way a UI 2.0 surface scrolls or drags sideways inside a page that scrolls up and down
//  (owner 2026-10-25, horizontal-scroll-yield). Two failure modes, both measured on device:
//
//  1. A coasting horizontal ScrollView claims the next touch before it has a direction (UIKit lets
//     a decelerating scroll view "catch" any touch), so a vertical swipe that lands on it never
//     reaches the page. `HorizontalRail` stops the coast at touch-down; the touch is then an
//     ordinary one, and its direction decides: up/down scrolls the page, sideways drags the rail.
//  2. A SwiftUI `DragGesture` — even attached with `simultaneousGesture` — holds a touch inside a
//     ScrollView, so the page under it cannot scroll. `.horizontalPan` is a UIKit pan that refuses
//     to begin unless the drag runs more sideways than up/down.
//
//  Enforced by `.swiftlint.yml` (`raw_horizontal_scrollview`, `sideways_drag_gesture`): a raw
//  `ScrollView(.horizontal` or an unannotated `DragGesture` in MakeReadyUI fails the build.
//

import SwiftUI
import UIKit

// MARK: - HorizontalRail

/// A sideways-scrolling row that never traps a vertical swipe. A drop-in for
/// `ScrollView(.horizontal)`: scroll modifiers applied to it (`scrollPosition`, `scrollIndicators`,
/// `contentMargins`, `onScrollGeometryChange`, `onScrollPhaseChange`, `scrollTargetBehavior`)
/// reach the scroll view inside, and scrolling stays free — no paging, no snapping.
struct HorizontalRail<Content: View>: View {
    private let showsIndicators: Bool
    private let content: Content

    init(showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: showsIndicators) {
            content.background(CoastBreaker())
        }
    }
}

/// Installs `CoastBreakerGesture` on the scroll view that encloses it.
private struct CoastBreaker: UIViewRepresentable {
    func makeUIView(context: Context) -> CoastBreakerView { CoastBreakerView() }
    func updateUIView(_ uiView: CoastBreakerView, context: Context) {}
}

private final class CoastBreakerView: UIView {
    private weak var installedOn: UIScrollView?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        isUserInteractionEnabled = false
        var view = superview
        while let current = view, !(current is UIScrollView) { view = current.superview }
        guard let scrollView = view as? UIScrollView, scrollView !== installedOn else { return }
        installedOn = scrollView
        scrollView.addGestureRecognizer(CoastBreakerGesture())
    }
}

/// Never recognizes and never cancels touches: it only halts the scroll view's momentum at
/// touch-down. Gesture recognizers see `touchesBegan` before the scroll view decides whether its
/// pan may begin, so the pan then judges the touch as an at-rest scroll view would.
private final class CoastBreakerGesture: UIGestureRecognizer, UIGestureRecognizerDelegate {
    override init(target: Any? = nil, action: Selector? = nil) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let scrollView = view as? UIScrollView, scrollView.isDecelerating {
            scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        }
        state = .failed
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

// MARK: - horizontalPan

/// One moment of a sideways pan, in points.
struct HorizontalPanValue: Equatable {
    var translation: CGFloat
    /// Points per second; positive is rightwards.
    var velocity: CGFloat

    init(translation: CGFloat, velocity: CGFloat) {
        self.translation = translation
        self.velocity = velocity
    }

    /// Where a fling would come to rest: the velocity projected the way a UIKit scroll view
    /// decelerates (`.normal` rate 0.998/ms → velocity × 0.499 s).
    var predictedEndTranslation: CGFloat { translation + velocity * Self.flingSeconds }

    static let flingSeconds: CGFloat = 0.499

    /// The direction rule: a pan begins only when it runs more sideways than up/down.
    static func begins(horizontal: CGFloat, vertical: CGFloat) -> Bool { abs(horizontal) > abs(vertical) }
}

extension View {
    /// A sideways drag that leaves vertical drags to the page it sits in. `onEnded` also runs, with
    /// zero velocity, when the system cancels the pan.
    func horizontalPan(onChanged: @escaping (HorizontalPanValue) -> Void,
                       onEnded: @escaping (HorizontalPanValue) -> Void) -> some View {
        gesture(HorizontalPan(onChanged: onChanged, onEnded: onEnded))
    }
}

private struct HorizontalPan: UIGestureRecognizerRepresentable {
    var onChanged: (HorizontalPanValue) -> Void
    var onEnded: (HorizontalPanValue) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        let translation = pan.translation(in: pan.view).x
        switch pan.state {
        case .began, .changed:
            onChanged(HorizontalPanValue(translation: translation, velocity: pan.velocity(in: pan.view).x))
        case .ended:
            onEnded(HorizontalPanValue(translation: translation, velocity: pan.velocity(in: pan.view).x))
        case .cancelled, .failed:
            onEnded(HorizontalPanValue(translation: translation, velocity: 0))
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return HorizontalPanValue.begins(horizontal: velocity.x, vertical: velocity.y)
        }
    }
}

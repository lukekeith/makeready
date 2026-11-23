//
//  VideoTrimBar.swift
//  MakeReady
//
//  video-recorder D8: the trim step's window over an imported clip longer than 2:00.
//

import SwiftUI

/// The trim window's arithmetic, in seconds.
enum VideoTrim {
    static let maxLength: Double = 120
    static let minLength: Double = 1

    enum Part { case start, end, whole }

    /// `window` with one part dragged by `delta`, inside the clip and between the shortest and the
    /// longest window.
    static func window(_ window: ClosedRange<Double>, dragging part: Part, by delta: Double, duration: Double) -> ClosedRange<Double> {
        let (lower, upper) = (window.lowerBound, window.upperBound)
        switch part {
        case .start:
            return min(max(lower + delta, 0, upper - maxLength), upper - minLength)...upper
        case .end:
            return lower...max(min(upper + delta, duration, lower + maxLength), lower + minLength)
        case .whole:
            let start = min(max(lower + delta, 0), duration - (upper - lower))
            return start...(start + upper - lower)
        }
    }

    /// Any range, cut to the clip and to the longest window.
    static func window(_ range: ClosedRange<Double>, duration: Double) -> ClosedRange<Double> {
        let start = min(max(range.lowerBound, 0), duration)
        return start...min(max(range.upperBound, start), duration, start + maxLength)
    }
}

struct VideoTrimBar: View {
    let duration: Double
    let window: ClosedRange<Double>
    let onChange: (ClosedRange<Double>) -> Void

    /// The drag in progress: what it moves and the window it began with.
    @State private var drag: (part: VideoTrim.Part, origin: ClosedRange<Double>)?
    @GestureState private var isDragging = false
    @State private var width: CGFloat = 1

    private enum Geometry {
        /// GAP — video-recorder §2d Trim draws no bar: the 44 pt target, and a handle's grip.
        static let height: CGFloat = 44
        static let handle: CGFloat = 12
        static let stroke: CGFloat = 2
        static let touch: CGFloat = 22
        /// What one accessibility adjustment moves the window by.
        static let adjustment: Double = 5
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Token.Radius.card)
                .fill(Token.black60)
            RoundedRectangle(cornerRadius: Token.Radius.card)
                .fill(Token.white20)
                .strokeBorder(Token.textPrimary, lineWidth: Geometry.stroke)
                .overlay(alignment: .leading) { handle }
                .overlay(alignment: .trailing) { handle }
                .frame(width: max(x(of: window.upperBound) - x(of: window.lowerBound), Geometry.handle * 2))
                .offset(x: x(of: window.lowerBound))
        }
        .frame(height: Geometry.height)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = max($0, 1) }
        .contentShape(Rectangle())
        .gesture(gesture)
        .onChange(of: isDragging) { _, dragging in
            if !dragging { drag = nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trim")
        .accessibilityValue("\(Int(window.lowerBound)) to \(Int(window.upperBound)) seconds")
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? Geometry.adjustment : -Geometry.adjustment
            onChange(VideoTrim.window(window, dragging: .whole, by: delta, duration: duration))
        }
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: Token.Radius.card)
            .fill(Token.textPrimary)
            .frame(width: Geometry.handle)
    }

    private func x(of seconds: Double) -> CGFloat {
        duration > 0 ? width * seconds / duration : 0
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isDragging) { _, dragging, transaction in
                dragging = true
                transaction.animation = nil
            }
            .onChanged { value in
                let current = drag ?? (part(at: value.startLocation.x), window)
                if drag == nil { drag = current }
                let delta = value.translation.width / width * duration
                onChange(VideoTrim.window(current.origin, dragging: current.part, by: delta, duration: duration))
            }
    }

    private func part(at location: CGFloat) -> VideoTrim.Part {
        let start = abs(location - x(of: window.lowerBound))
        let end = abs(location - x(of: window.upperBound))
        guard min(start, end) <= Geometry.touch else { return .whole }
        return start < end ? .start : .end
    }
}

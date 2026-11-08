import Foundation

/// text-activity D10: the viewer's position engine, `docs/features/activity-viewer/01-experience.md` sections 4-8.
///
/// A pure state machine. It takes touch samples and clock ticks and reports positions, the active page and the
/// rail window; it imports nothing but Foundation, and the renderer (a UIKit pan recognizer plus CADisplayLink)
/// applies what it reads. `viewer-engine-vectors.json` is the contract a TypeScript engine loads too.
///
/// Sign convention: `dy`, `velocity`, `drag` and `inner` all grow in the reading direction. A finger moving UP
/// the screen gives a positive `dy`, pulls the next page in (`drag > 0`) or scrolls the page's content
/// forward (`inner` grows). Time is in seconds, velocity in points per second.
///
/// Build-time risk (F4): `velocityProjection = 0.25` and `springOmega = 20` are measured brackets, not exact
/// values. The device feel check (01 section 13, walk item 6) may retune them; record any change here and in
/// the vectors. Current values: as the spec's 2026-11-06 defaults, unchanged.
///
/// Decisions the spec leaves open, made here:
/// - The settle never overshoots its target. When a release velocity is high enough that the closed form
///   `x(t)` would cross zero (v0 > omega * x0), the settle ends at the target instead (01 section 6: overshoot none).
/// - Pulling past the LAST page follows the finger 1:1 and returns on lift; the host reads that distance for
///   the completion-page dismissal (01 section 11).
struct ViewerEngine {
    enum Owner: Equatable {
        case none, inner, pager
    }

    /// A critically damped spring toward `targetPage`, started at the release velocity.
    struct Settle: Equatable {
        /// The page the stack lands on.
        var targetPage: Int
        /// The target's `drag` relative to the anchor at lift: 0 (return), `viewportHeight` or `-viewportHeight`.
        var targetDrag: Double
        /// Direction of travel toward the target: +1 when it is above the current `drag`, -1 when below.
        var direction: Double
        /// Remaining distance at lift, and the speed toward the target at lift (negative when moving away).
        var remaining: Double
        var velocity: Double
        var elapsed: Double = 0
    }

    enum Output: Equatable {
        /// The page covering the midline changed (01 section 7). Fired at the crossing, with or without a finger.
        case activeChanged(Int)
        /// A settle landed. Progress counts a page as viewed from here, never mid-drag.
        case settled(Int)
        /// A release chose to move to another page; the spring starts now.
        case commitStarted(to: Int)
    }

    static let velocityProjection = 0.25
    static let springOmega = 20.0
    static let edgeResistance = 0.55
    /// Momentum decay per millisecond (iOS default deceleration).
    static let momentumDecay = 0.998
    static let endEpsilon = 0.5
    static let endSpeed = 5.0

    var viewportHeight: Double
    var pageHeights: [Double]
    var anchor: Int
    var drag: Double = 0
    var inner: [Double]
    var owner: Owner = .none
    var activePage: Int
    var settle: Settle?
    /// Scroll momentum after an `inner`-owned lift, points per second.
    var momentum: Double = 0
    /// Pages already revealed this session. A page's `inner` is kept; only a first reveal sets its start.
    var visitedPages: Set<Int>

    init(viewportHeight: Double, pageHeights: [Double], anchor: Int = 0) {
        self.viewportHeight = viewportHeight
        self.pageHeights = pageHeights
        self.anchor = anchor
        self.inner = Array(repeating: 0, count: pageHeights.count)
        self.visitedPages = [anchor]
        self.activePage = anchor
    }

    // MARK: Derived

    /// The page covering the viewport's horizontal midline: it changes the instant `|drag|` passes half the viewport.
    var pageCoveringMidline: Int {
        let half = viewportHeight / 2
        if drag > half, anchor + 1 < pageHeights.count { return anchor + 1 }
        if drag < -half, anchor > 0 { return anchor - 1 }
        return anchor
    }

    /// The most a page can scroll inside its viewport-tall window.
    func maxInner(page: Int) -> Double {
        guard pageHeights.indices.contains(page) else { return 0 }
        return max(0, pageHeights[page] - viewportHeight)
    }

    /// The rail's thumb position, `inner / maxInner`; nil when the page has no scroll range (01 section 8).
    func thumbFraction(page: Int) -> Double? {
        let maximum = maxInner(page: page)
        guard maximum > 0, inner.indices.contains(page) else { return nil }
        return min(1, max(0, inner[page] / maximum))
    }

    /// Which pages the rail shows: a window of at most five that contains the active page (01 section 8).
    static func railWindow(active: Int, pageCount: Int) -> (start: Int, slots: Int) {
        let slots = min(5, max(0, pageCount))
        let start = min(max(active - 2, 0), pageCount - slots)
        return (max(0, start), slots)
    }

    // MARK: Touch

    /// A finger lands. During a settle it stops the spring and takes over with `pager` ownership, and `anchor`
    /// becomes the page covering the midline (01 section 6).
    mutating func touchBegan() {
        momentum = 0
        guard settle != nil else {
            owner = .none
            return
        }
        settle = nil
        let page = pageCoveringMidline
        drag -= Double(page - anchor) * viewportHeight
        anchor = page
        owner = .pager
    }

    /// The finger moved by `dy`. Ownership is decided here at the first movement and held until lift (01 section 5).
    mutating func touchMoved(dy: Double) -> [Output] {
        guard dy != 0 else { return [] }
        if owner == .none {
            if dy > 0 {
                owner = inner(anchor) < maxInner(page: anchor) ? .inner : .pager
            } else {
                owner = inner(anchor) > 0 ? .inner : .pager
            }
        }
        switch owner {
        case .inner:
            inner[anchor] = min(maxInner(page: anchor), max(0, inner(anchor) + dy))
        case .pager:
            movePager(by: dy)
        case .none:
            break
        }
        return publishActive()
    }

    /// The finger lifted at `velocity`. A `pager` release with `drag != 0` snaps (01 section 6); an `inner`
    /// release starts momentum.
    mutating func touchEnded(velocity: Double) -> [Output] {
        defer { if settle != nil || owner != .inner { owner = .none } }
        switch owner {
        case .pager where drag != 0:
            return beginSettle(velocity: velocity)
        case .inner:
            momentum = abs(velocity) < Self.endSpeed ? 0 : velocity
            if momentum == 0 { owner = .none }
            return []
        default:
            return []
        }
    }

    // MARK: Clock

    /// Advance by `dt` seconds: the settle spring, or the scroll momentum.
    mutating func tick(dt: Double) -> [Output] {
        if settle != nil { return tickSettle(dt: dt) }
        if momentum != 0 { tickMomentum(dt: dt) }
        return []
    }

    // MARK: Pager

    private func inner(_ page: Int) -> Double { inner.indices.contains(page) ? inner[page] : 0 }

    /// 1:1 across rest in both directions; past the first page's top the finger moves at `edgeResistance`.
    /// A neighbor that fully covers the viewport becomes the anchor and the touch stays with the pager.
    private mutating func movePager(by dy: Double) {
        var remaining = dy
        var position = drag
        if anchor == 0 {
            // The resisted region is `position < 0`: the finger travels 1/0.55 points per point of drag.
            if position < 0 {
                let fingerToRest = -position / Self.edgeResistance
                if remaining >= fingerToRest {
                    remaining -= fingerToRest
                    position = 0
                } else {
                    position += remaining * Self.edgeResistance
                    remaining = 0
                }
            } else if position + remaining < 0 {
                remaining += position
                position = remaining * Self.edgeResistance
                remaining = 0
            }
        }
        drag = position + remaining
        rebaseAnchor()
        revealNeighbor()
    }

    private mutating func rebaseAnchor() {
        while drag >= viewportHeight, anchor + 1 < pageHeights.count {
            anchor += 1
            drag -= viewportHeight
        }
        while drag <= -viewportHeight, anchor > 0 {
            anchor -= 1
            drag += viewportHeight
        }
    }

    /// A page's first reveal sets where it starts: 0 from above, its max from below (01 section 4).
    private mutating func revealNeighbor() {
        if drag > 0, anchor + 1 < pageHeights.count {
            visitedPages.insert(anchor + 1)
        } else if drag < 0, anchor > 0, !visitedPages.contains(anchor - 1) {
            visitedPages.insert(anchor - 1)
            inner[anchor - 1] = maxInner(page: anchor - 1)
        }
    }

    private mutating func publishActive() -> [Output] {
        let page = pageCoveringMidline
        guard page != activePage else { return [] }
        activePage = page
        return [.activeChanged(page)]
    }

    // MARK: Snapping

    private mutating func beginSettle(velocity: Double) -> [Output] {
        let half = viewportHeight / 2
        let projected = drag + velocity * Self.velocityProjection
        var targetPage = anchor
        var targetDrag = 0.0
        if projected > half, anchor + 1 < pageHeights.count {
            targetPage = anchor + 1
            targetDrag = viewportHeight
        } else if projected < -half, anchor > 0 {
            targetPage = anchor - 1
            targetDrag = -viewportHeight
        }
        let direction: Double = targetDrag >= drag ? 1 : -1
        settle = Settle(targetPage: targetPage, targetDrag: targetDrag, direction: direction,
                        remaining: abs(targetDrag - drag), velocity: velocity * direction)
        return targetPage == anchor ? [] : [.commitStarted(to: targetPage)]
    }

    private mutating func tickSettle(dt: Double) -> [Output] {
        guard var spring = settle else { return [] }
        spring.elapsed += dt
        let omega = Self.springOmega
        let t = spring.elapsed
        let decay = exp(-omega * t)
        // x(t) = (x0 + (omega x0 - v0) t) e^(-omega t), the distance still to go.
        let distance = (spring.remaining + (omega * spring.remaining - spring.velocity) * t) * decay
        let speed = abs((-spring.velocity - omega * (omega * spring.remaining - spring.velocity) * t) * decay)
        var outputs: [Output] = []
        if distance <= 0 || (distance < Self.endEpsilon && speed < Self.endSpeed) {
            settle = nil
            anchor = spring.targetPage
            drag = 0
            outputs += publishActive()
            outputs.append(.settled(spring.targetPage))
            return outputs
        }
        settle = spring
        drag = spring.targetDrag - spring.direction * distance
        revealNeighbor()
        return publishActive()
    }

    // MARK: Momentum

    /// Scroll momentum decays at 0.998 per millisecond and stops at either limit, with no spill into `drag`.
    private mutating func tickMomentum(dt: Double) {
        momentum *= pow(Self.momentumDecay, dt * 1000)
        let next = inner(anchor) + momentum * dt
        let limit = maxInner(page: anchor)
        if next <= 0 || next >= limit {
            inner[anchor] = min(limit, max(0, next))
            momentum = 0
        } else {
            inner[anchor] = next
            if abs(momentum) < Self.endSpeed { momentum = 0 }
        }
        if momentum == 0 { owner = .none }
    }
}

import SwiftUI

/// SPEC D14: the finger-tracked morph's math. C-019 §4: "`expansion` 0…1 — the analysis's
/// finger-tracked, reversible, spring-settled model"; analysis §8 note 2: "release settles to
/// 0 or 1 by position+velocity".
enum TopNavDrag {
    /// C-019 §2: row height 32 collapsed · 96 expanded → 64pt of vertical drag spans the
    /// whole morph. Read from C-069 (the one owner of the row height), not restated.
    static var travel: CGFloat { NavTabButton.height(at: 1) - NavTabButton.height(at: 0) }

    /// GAP — no flick threshold in C-019 or the analysis (§6: "Vertical flick … commits the
    /// morph to the nearest/target state"): 500 pt/s, no motion token.
    static let flickVelocity: CGFloat = 500

    static func expansion(from start: Double, translation: CGFloat, travel: CGFloat) -> Double {
        guard travel > 0 else { return start }
        return min(1, max(0, start + Double(translation / travel)))
    }

    /// The drag's axis: `true` = vertical (scrubs the morph). Decided by the first movement and
    /// never re-decided — once `current` is set it wins (review I-1).
    static func lockAxis(_ current: Bool?, translation: CGSize) -> Bool {
        current ?? (abs(translation.height) > abs(translation.width))
    }

    /// One gesture's axis lock, keyed by the gesture's start location. A cancelled drag (scroll
    /// takeover, tab switch, view removal) never reaches `onEnded`, so a lock cleared only there
    /// would leak into the next drag; keying it by `startLocation` makes every new gesture
    /// re-lock on its first movement. `lockAxis` stays the one decision function.
    struct AxisLock {
        private var start: CGPoint?
        private var vertical: Bool?

        /// `.onChanged`: a start different from the stored one is a new gesture → re-lock.
        mutating func update(start: CGPoint, translation: CGSize) -> Bool {
            if start != self.start {
                self.start = start
                vertical = nil
            }
            let locked = TopNavDrag.lockAxis(vertical, translation: translation)
            vertical = locked
            return locked
        }

        /// `onEnded`: this gesture's lock (or a fresh decision if it never changed), then clear.
        mutating func end(start: CGPoint, translation: CGSize) -> Bool {
            let locked = TopNavDrag.lockAxis(start == self.start ? vertical : nil, translation: translation)
            self.start = nil
            vertical = nil
            return locked
        }
    }

    /// Flick wins over position past `flickVelocity`; otherwise the nearer end.
    static func settle(_ value: Double, velocity: CGFloat) -> Double {
        if velocity > flickVelocity { return 1 }
        if velocity < -flickVelocity { return 0 }
        return value >= 0.5 ? 1 : 0
    }
}

/// SPEC D11/D14: hosts C-019 TopNav for the shell. TopNav has only a tap gesture; the
/// vertical drag that scrubs `expansion` lives here (C-019 §4 `onToggleExpansion`: "Tap
/// toggles; vertical drag scrubs `expansion`").
struct TopNavHost: View {
    @Binding var model: UI2ShellModel

    /// GAP — docs/features/navigation/01-account-switcher-analysis.md §6: "commits the morph
    /// … with a spring (~300ms)": spring, 0.3s, no bounce, no motion token. One curve for
    /// expand, collapse, tap toggle and the select-collapse (transition-review E3).
    static let morphDuration: TimeInterval = 0.3
    static let morphSpring = Animation.spring(duration: morphDuration, bounce: 0)

    /// A vertical drag writes `model.expansion` itself as the finger moves, and the release
    /// springs on from that same value. (It used to ride on a `@GestureState` offset over the
    /// committed value; the offset reset the instant the finger lifted while the spring started
    /// from the drag's START, so the row snapped back a frame and morphed through its middle
    /// again, and the page — fed the offset a frame late — split from the row. On-device
    /// recording 2026-10-25.)
    /// The expansion when this vertical drag began; nil when no vertical drag runs.
    @State private var dragStart: Double?
    /// Per-gesture axis lock (D43), keyed by `startLocation` (see AxisLock).
    @State private var axisLock = TopNavDrag.AxisLock()
    /// True while the drag gesture is live; its reset without `onEnded` is a cancelled drag.
    @GestureState private var dragging = false

    var body: some View {
        TopNav(
            tabs: UI2Section.allCases.map(\.rawValue),
            selectedTab: model.section.rawValue,
            expansion: model.expansion,
            scrollOffset: model.scrollOffset,
            onSelect: select,
            onToggleExpansion: toggle,
            // The Members `add` opens the invite flow, exactly as the Add menu's row does (owner
            // 2026-10-26); the Groups `add` pushes create-group on the Home stack (ui2-groups-browse
            // D7/D8, OQ-groups-home-2); the Programs `add` pushes create-study-program (ui2-programs
            // D1/D8); the Enrollments `add` opens the enroll checklist with nothing preloaded
            // (ui2-enrollment-create D2); the other add slots stay no-ops (SPEC D10).
            onAdd: { tab in
                switch UI2Section(rawValue: tab) {
                case .members?: InviteEntry.open(on: .home, model: $model)
                case .groups?: model.push(.createGroup, on: .home)
                case .programs?: model.push(.createStudyProgram, on: .home)  // ui2-programs D1/D8
                case .enrollments?:                                            // ui2-enrollment-create D2
                    EnrollEntry.open(groupId: nil, studyProgramId: nil, push: { model.push($0, on: .home) })
                default: return
                }
            },
            pin: model.topNavPin
        )
        // Simultaneous so TopNav's own horizontal ScrollView keeps its pan; only a drag whose
        // first movement is vertical scrubs the morph (analysis §6: horizontal pan scrolls,
        // vertical drag morphs).
        .simultaneousGesture(morphDrag)
        // A drag the system cancelled (no `onEnded`) still settles, from where it stopped.
        .onChange(of: dragging) { _, live in
            if !live, dragStart != nil { settle(velocity: 0) }
        }
    }

    private var morphDrag: some Gesture {
        // GAP — no drag-start distance in C-019 §4 or analysis §6 ("Vertical drag | nav row |
        // scrubs the morph"): 8pt so a tap on a tab is not read as a drag, no token.
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($dragging) { _, state, _ in state = true }
            .onChanged { value in
                // A drag that began horizontal scrolls the row and never scrubs.
                guard axisLock.update(start: value.startLocation, translation: value.translation) else { return }
                // A new vertical drag pins the tab under its start (taking over a settle still
                // running). TopNav spans the screen width (C-019 §2: no host inset), so the global
                // x is TopNav's own x.
                if dragStart == nil {
                    TopNavMorph.shared.cancel()
                    model.topNavPin = TopNav.Pin(x: value.startLocation.x, animation: nil)
                }
                let start = dragStart ?? model.expansion
                dragStart = start
                // Finger-tracked: no animation, so a spring still running from a tap or the page
                // trigger is taken over at its current value.
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    model.expansion = TopNavDrag.expansion(
                        from: start, translation: value.translation.height, travel: TopNavDrag.travel
                    )
                }
            }
            .onEnded { value in
                let vertical = axisLock.end(start: value.startLocation, translation: value.translation)
                // A drag that began horizontal scrolled the row and never scrubbed: no morph.
                guard vertical, dragStart != nil else { return }
                settle(velocity: value.velocity.height)
            }
    }

    /// A vertical drag ends: spring from the value the finger left to the nearer end, or the
    /// flick's end (`TopNavDrag.settle`).
    private func settle(velocity: CGFloat) {
        dragStart = nil
        let target = TopNavDrag.settle(model.expansion, velocity: velocity)
        // A drag that already reached its end (the usual full pull) animates nothing, and a
        // completion with nothing to wait on is not guaranteed to run — let go now, or the pin
        // outlives the drag and the page's own pull-to-expand re-scrolls the row (owner 2026-10-29).
        guard target != model.expansion else { model.topNavPin = nil; return }
        // The finger's pin stays on through the settle, which runs frame by frame (TopNavMorph).
        TopNavMorph.shared.run($model, to: target, duration: Self.morphDuration, pin: model.topNavPin)
    }

    private func select(_ label: String) {
        guard let section = UI2Section(rawValue: label) else { return }
        // SPEC D14(b), revised 2026-10-25: the row keeps its expansion across a switch.
        withAnimation(Self.morphSpring) { model.apply(.section(section)) }
    }

    private func toggle() {
        Self.morph($model, to: model.expansion < 0.5 ? 1 : 0, duration: Self.morphDuration)
    }

    /// A morph with no finger on the row — a tap toggle, the page's pull-to-expand or its
    /// scroll-collapse: the selected tab holds where it sits (owner 2026-10-29: "always pin the
    /// current selected tab"; a top-nav drag pins the finger's tab instead).
    static func morph(_ model: Binding<UI2ShellModel>, to value: Double, duration: TimeInterval) {
        guard value != model.wrappedValue.expansion else { return }
        let pin = TopNav.Pin(tab: model.wrappedValue.section.rawValue, animation: nil)
        TopNavMorph.shared.run(model, to: value, duration: duration, pin: pin)
    }
}

/// Runs a morph frame by frame along a no-bounce spring, writing `expansion` on every display
/// frame, exactly as a finger drag does. A `withAnimation` morph jumps the model value to its
/// end and leaves TopNav one animated `scrollTo`, solved against the collapsed layout and never
/// corrected while the tabs grow — the pinned tab slid off (on-device recording 2026-10-29).
/// Stepping the value lets TopNav re-pin on every `expansion` change, as it does under a drag.
@MainActor
final class TopNavMorph: NSObject {
    static let shared = TopNavMorph()

    private var link: CADisplayLink?
    private var model: Binding<UI2ShellModel>?
    private var spring = Spring(duration: 0.3, bounce: 0)
    private var from = 0.0
    private var to = 0.0
    private var start: CFTimeInterval = 0
    private var pin: TopNav.Pin?

    /// Starts a morph to `value`, taking over one still running from where it is; `pin` is set
    /// now and released when the morph ends (unless something else took the pin meanwhile).
    func run(_ model: Binding<UI2ShellModel>, to value: Double, duration: TimeInterval, pin: TopNav.Pin?) {
        cancel()
        self.model = model
        spring = Spring(duration: duration, bounce: 0)
        from = model.wrappedValue.expansion
        to = value
        self.pin = pin
        if let pin { write { $0.topNavPin = pin } }
        start = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// Stops a running morph where it is — a finger drag takes over. The pin is left to the caller.
    func cancel() {
        link?.invalidate()
        link = nil
        model = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let elapsed = link.targetTimestamp - start
        let done = elapsed >= spring.settlingDuration
        let value = done ? to : from + spring.value(target: to - from, time: elapsed)
        write { $0.expansion = value }
        guard done else { return }
        let pin = pin
        write { if $0.topNavPin == pin { $0.topNavPin = nil } }
        cancel()
    }

    /// Model writes carry no animation: the morph IS the animation.
    private func write(_ change: (inout UI2ShellModel) -> Void) {
        guard let model else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { change(&model.wrappedValue) }
    }
}

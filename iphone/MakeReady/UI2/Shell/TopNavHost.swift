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
    static let morphSpring = Animation.spring(duration: 0.3, bounce: 0)

    /// The live drag (transition-review C1: `@GestureState`, reset without animation).
    @GestureState private var drag = DragTrack()
    /// The same lock, kept where `onEnded` can read it (`@GestureState` has already reset by
    /// then). Ephemeral gesture state (D43); per-gesture via `startLocation` (see AxisLock).
    @State private var axisLock = TopNavDrag.AxisLock()

    var body: some View {
        TopNav(
            tabs: UI2Section.allCases.map(\.rawValue),
            selectedTab: model.section.rawValue,
            expansion: liveExpansion,
            scrollOffset: model.scrollOffset,
            onSelect: select,
            onToggleExpansion: toggle,
            onAdd: { _ in }                                  // SPEC D10: add slots are no-ops
        )
        // Simultaneous so TopNav's own horizontal ScrollView keeps its pan; only a drag whose
        // first movement is vertical scrubs the morph (analysis §6: horizontal pan scrolls,
        // vertical drag morphs).
        .simultaneousGesture(morphDrag)
    }

    /// The committed value plus the finger's contribution while a vertical drag is live.
    private var liveExpansion: Double {
        TopNavDrag.expansion(from: model.expansion, translation: drag.translation, travel: TopNavDrag.travel)
    }

    private var morphDrag: some Gesture {
        // GAP — no drag-start distance in C-019 §4 or analysis §6 ("Vertical drag | nav row |
        // scrubs the morph"): 8pt so a tap on a tab is not read as a drag, no token.
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($drag) { value, state, transaction in
                transaction.animation = nil
                state.isVertical = TopNavDrag.lockAxis(state.isVertical, translation: value.translation)
                state.translation = state.isVertical == true ? value.translation.height : 0
            }
            .onChanged { value in
                _ = axisLock.update(start: value.startLocation, translation: value.translation)
            }
            .onEnded { value in
                let vertical = axisLock.end(start: value.startLocation, translation: value.translation)
                // A drag that began horizontal scrolled the row and never scrubbed: no morph.
                guard vertical else { return }
                // A drag that began vertical always settles with the spring, however it ends.
                let released = TopNavDrag.expansion(
                    from: model.expansion, translation: value.translation.height, travel: TopNavDrag.travel
                )
                withAnimation(Self.morphSpring) {
                    model.expansion = TopNavDrag.settle(released, velocity: value.velocity.height)
                }
            }
    }

    private func select(_ label: String) {
        guard let section = UI2Section(rawValue: label) else { return }
        // SPEC D14: "Selecting a card collapses the row" — `apply(.section)` zeroes expansion.
        withAnimation(Self.morphSpring) { model.apply(.section(section)) }
    }

    private func toggle() {
        withAnimation(Self.morphSpring) { model.expansion = model.expansion < 0.5 ? 1 : 0 }
    }
}

/// The in-flight drag: its axis is decided by the first movement and kept for the gesture.
private struct DragTrack {
    var isVertical: Bool?
    var translation: CGFloat = 0
}

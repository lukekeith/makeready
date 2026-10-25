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
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($drag) { value, state, transaction in
                transaction.animation = nil
                if state.isVertical == nil {
                    state.isVertical = abs(value.translation.height) > abs(value.translation.width)
                }
                state.translation = state.isVertical == true ? value.translation.height : 0
            }
            .onEnded { value in
                let vertical = abs(value.translation.height) > abs(value.translation.width)
                guard vertical else { return }
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

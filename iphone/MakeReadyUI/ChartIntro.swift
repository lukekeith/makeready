import SwiftUI

/// dashboard-chart-intros — the intro a chart plays the first time its Home section reveals.
///
/// D7: every chart takes `ChartIntro?` and `nil` is the still render it draws today — what
/// ViewRegistry, `/compare`, the d2m fixtures and every other screen pass. A non-nil intro flips
/// `played` false → true once per visit; charts key implicit animations on that flip, so the
/// start pose animates to a final pose identical to the `nil` render. No timed choreography.
struct ChartIntro: Equatable {
    /// false = the start pose; true = the final pose (the `nil` render).
    var played: Bool
    /// D10: crossfade only — no scale, translation, sweep, wave or count-up; data changes snap.
    var reduceMotion: Bool = false
    /// Seconds before this chart's first element moves (a rail card's cascade, D8).
    var delay: Double = 0

    /// 0 = start pose, 1 = final pose. D10/D16: a fade-only intro is final from the first frame.
    func progress(fadeOnly: Bool) -> Double {
        (fadeOnly || reduceMotion || played) ? 1 : 0
    }

    /// The crossfade (D10/D16): 0 until played, for a fade-only intro; otherwise always 1.
    func opacity(fadeOnly: Bool) -> Double {
        (fadeOnly || reduceMotion) && !played ? 0 : 1
    }

    /// One element's intro animation, `extra` seconds after this chart's own delay — nil under
    /// Reduce Motion, so geometry never moves (D10).
    func animation(_ base: Animation, after extra: Double = 0) -> Animation? {
        reduceMotion ? nil : base.delay(delay + extra)
    }

    /// D9: data behind a played chart moves old → new; D10: it snaps under Reduce Motion.
    var morph: Animation? { reduceMotion ? nil : ChartIntroMotion.morph }

    /// The same intro, starting `extra` seconds later (a card forwarding to its chart).
    func delayed(by extra: Double) -> ChartIntro {
        ChartIntro(played: played, reduceMotion: reduceMotion, delay: delay + extra)
    }

    /// A length at intro progress `progress` — the still length at 1.
    static func scaled(_ length: CGFloat, by progress: Double) -> CGFloat {
        length * CGFloat(progress)
    }
}

// GAP — Token.Motion has no chart-intro entries (dashboard-chart-intros D12/D13); the owner
// files rise, draw, count-up, overshoot and morph in the d2m token register. Tokens.swift is
// generated and is not edited. Values tuned at the walk within D3 (each intro ≤ 1.2 s).
enum ChartIntroMotion {
    static let rise = Animation.spring(duration: 0.6, bounce: 0.15)
    static let draw = Animation.easeOut(duration: 0.5)
    static let countUp = Animation.easeOut(duration: 0.8)
    static let overshoot = Animation.spring(duration: 0.8, bounce: 0.25)
    static let morph = Animation.easeInOut(duration: 0.4)
    /// D10: the Reduce Motion / empty-chart crossfade.
    static let fade = Animation.easeOut(duration: 0.2)

    /// D3: ≈ 15 ms between bars…
    static let staggerStep: Double = 0.015
    /// …shrunk so the last bar of any wave starts by 0.6 s, leaving the rise inside 1.2 s.
    static let waveBudget: Double = 0.6
    /// D8: between rail cards in a cascade.
    static let cascadeStep: Double = 0.06

    /// The delay of element `index` in a left-to-right wave of `count`.
    static func stagger(_ index: Int, of count: Int) -> Double {
        guard count > 1, index > 0 else { return 0 }
        let step = min(staggerStep, waveBudget / Double(count - 1))
        return Double(min(index, count - 1)) * step
    }

    /// D2 Sessions: when the clock's sweep reaches `hour` (0 = midnight) — the same 0.6 s the
    /// TimeActivityChart's wave spans, so the two move in step.
    static func sweepDelay(hour: Int) -> Double {
        Double(min(max(hour, 0), 24)) / 24 * waveBudget
    }
}

extension View {
    /// D10/D16: the crossfade. Inert when `intro` is nil.
    func chartIntroFade(_ intro: ChartIntro?, fadeOnly: Bool = false) -> some View {
        opacity(intro?.opacity(fadeOnly: fadeOnly) ?? 1)
            .animation(intro == nil ? nil : ChartIntroMotion.fade, value: intro?.played)
    }

    /// D9: the morph when the data behind a chart changes. No animation with no intro.
    func chartIntroMorph<V: Equatable>(_ intro: ChartIntro?, value: V) -> some View {
        animation(intro?.morph, value: value)
    }
}

extension EnvironmentValues {
    /// D6/D15 (revised 2026-10-26): whether the Home tab is the selected tab. The shell sets it
    /// from `UI2ShellModel.homeActive`; every other host leaves the default.
    @Entry var chartIntroActive: Bool = true
}

import SwiftUI

/// SPEC D14 (ui2-shell) → media-page D16: when a section's vertical scroll opens or closes the TopNav row.
/// The shell's page scroll and a section that owns its scroll (Media's grid) report through this one rule.
enum SectionScrollMorph {
    // GAP — no pull distance in C-019; the reference fires on a short pull: 12pt past the top.
    static let expandPull: CGFloat = 12
    // GAP — the reference collapses as soon as the page moves up: 8pt, past touch jitter.
    static let collapseScroll: CGFloat = 8
    // GAP — the page-triggered morph settles in ~130ms in the reference.
    static let triggerDuration: TimeInterval = 0.15

    /// The expansion to morph to, or nil to leave the row alone. `offset` is the scroll's distance from
    /// its top including insets (negative = pulled past the top).
    static func target(expansion: Double, interacting: Bool, offset: CGFloat) -> Double? {
        if expansion == 0, interacting, offset <= -expandPull { return 1 }
        if expansion == 1, offset >= collapseScroll { return 0 }
        return nil
    }
}

/// media-page D16: how a section that owns its scroll reports it to the shell's TopNav.
struct SectionScrollReport {
    let report: @MainActor (_ offset: CGFloat, _ interacting: Bool) -> Void
    static let none = SectionScrollReport { _, _ in }
}

private struct SectionScrollReportKey: EnvironmentKey {
    static let defaultValue = SectionScrollReport.none
}

extension EnvironmentValues {
    var sectionScrollReport: SectionScrollReport {
        get { self[SectionScrollReportKey.self] }
        set { self[SectionScrollReportKey.self] = newValue }
    }
}

extension UI2Section {
    /// media-page D16: the section draws its own vertical scroll (Media's bottom-anchored, pinch-zoomed
    /// grid can't nest in the page scroll). Every other section keeps `SectionPageScroll`.
    var ownsScroll: Bool { self == .media }
}

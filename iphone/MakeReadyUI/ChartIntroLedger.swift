import SwiftUI

/// dashboard-chart-intros D5/D6/D15: which Home sections have played their intro this visit.
/// View state on HomeDashboardScreen (`@State`) — nothing else reads it and it is not persisted.
struct ChartIntroLedger: Equatable {
    enum Section: String, CaseIterable {
        case overview, activity, sessions, engagement
    }

    private(set) var played: Set<Section> = []
    /// The sections ≥ 50 % visible right now (D4), kept so a return to Home can replay them.
    private(set) var visible: Set<Section> = []
    /// D15: false while another tab is selected.
    private(set) var active = true

    func hasPlayed(_ section: Section) -> Bool { played.contains(section) }

    /// D4: at least half of the section's height is inside the page scroll's visible bounds.
    /// Measured, not `onScrollVisibilityChange`: on a section holding its own horizontal rail
    /// (Overview, Activity) that reported a reveal at ~22 % (agent walk round 1).
    static func isRevealed(_ section: CGRect, in visible: CGRect, threshold: CGFloat = 0.5) -> Bool {
        guard section.height > 0 else { return false }
        let shown = section.intersection(visible)
        return !shown.isNull && shown.height >= section.height * threshold
    }

    /// D4/D5: a section crossed the 50 % line. It plays the first time it is seen this visit.
    mutating func setVisible(_ section: Section, _ isVisible: Bool) {
        if isVisible {
            visible.insert(section)
            if active { played.insert(section) }
        } else {
            visible.remove(section)
        }
    }

    /// D6/D15: leaving Home clears every flag while the page is hidden; returning plays the
    /// sections still on screen (their visibility never changed, audit F4).
    mutating func setActive(_ isActive: Bool) {
        guard isActive != active else { return }
        active = isActive
        played = isActive ? visible : []
    }
}

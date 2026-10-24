//
//  EnrollmentProgressHeader.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-125-enrollment-progress-header in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-125 EnrollmentProgressHeader — "the Enrollment checklist's hero and status bar".
///
/// §2: a centred vertical stack — Hero (112), Text block, Status block — separated by
/// `space-section-gap`. Full width (376 in every design), intrinsic height 287.
///
/// Chrome-free (R-16, §1 deviation 1): the header fills the width it is given and states its
/// own height; it paints no page background and adds no outer padding. Frame, background and
/// margin belong to the ViewRegistry call site.
///
/// §4, in the rulebook's shape: R-05 flat parameters in the contract's order, R-07 all
/// required, R-01/R-03 controlled and display-only — no state, no callbacks. The title, the
/// subtitle copy, the readout and the bar's progress are derived (§4 "Derived, not props").
struct EnrollmentProgressHeader: View {

    /// C-125 §4 `groupName` — `nil` → the + disc and the generic subtitle; non-nil → the
    /// Avatar and "…to finish the enrollment for {groupName}."
    let groupName: String?
    /// C-125 §4 `groupImageURL` — passed to C-038 `imageURL`. Read only when `groupName` is set.
    let groupImageURL: URL?
    /// C-125 §4 `groupInitials` — passed to C-038 `initials`. Read only when `groupName` is set.
    let groupInitials: String?
    /// C-125 §4 `completedSteps` — checklist rows done. Clamped to 0…totalSteps.
    let completedSteps: Int
    /// C-125 §4 `totalSteps` — checklist rows in all. `0` renders 0%.
    let totalSteps: Int

    var body: some View {
        VStack(spacing: Token.Space.sectionGap) {
            hero
            textBlock
            statusBlock
        }
        .frame(maxWidth: .infinity)
        // §2: "The block reads as one accessibility element".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(subtitleString). Enrollment status, \(percent) percent.")
        .ui2Element("EnrollmentProgressHeader")
    }

    // MARK: - Derived (§4)

    /// §4: `completedSteps` clamped to 0…totalSteps.
    private var clampedCompleted: Int {
        min(max(completedSteps, 0), max(totalSteps, 0))
    }

    /// §4: the bar's `progress = completedSteps ÷ totalSteps`; `totalSteps == 0` renders 0.
    private var progress: Double {
        totalSteps > 0 ? Double(clampedCompleted) / Double(totalSteps) : 0
    }

    /// §4: the readout `round(completed ÷ total × 100)`.
    private var percent: Int {
        Int((progress * 100).rounded())
    }

    /// §1 deviation 5 / §6: "Enrollment ready" only when every step is done.
    private var isComplete: Bool {
        totalSteps > 0 && clampedCompleted == totalSteps
    }

    /// §2 B: "New Enrollment" | "Enrollment ready".
    private var title: String {
        isComplete ? "Enrollment ready" : "New Enrollment"
    }

    /// §2 B, the subtitle as plain text (the accessibility label reads it).
    private var subtitleString: String {
        if let groupName {
            return Self.groupSubtitleLead + groupName + "."
        }
        return Self.noGroupSubtitle
    }

    private static let noGroupSubtitle = "Complete the information below to enroll a group in a study program"
    private static let groupSubtitleLead = "Complete the information below to finish the enrollment for "

    // MARK: - A. Hero

    @ViewBuilder
    private var hero: some View {
        if groupName != nil {
            // §2 A / §1 deviation 6: C-038 Avatar at 112, state derived from content
            // (OQ-C-125-003: no photo → C-038 Initials at 112).
            Avatar(imageURL: groupImageURL, initials: groupInitials, size: Geometry.hero)
                .ui2Element("Hero")
        } else {
            addPlaceholderDisc
                .ui2Element("Hero")
        }
    }

    /// §2 A AddPlaceholderDisc (inline part, not a row): a `radius-circle` disc filled
    /// `color-white-20`, `add-large-carbon` 44×44 centred, tinted `color-white-50`.
    /// `radius-circle` is NOT PARSED in Tokens.swift ("50%"), so the circle is the shape itself.
    private var addPlaceholderDisc: some View {
        Circle()
            .fill(Token.white20)
            .frame(width: Geometry.hero, height: Geometry.hero)
            .overlay {
                // No `GlyphSize` case is 44, so the imageset is sized here directly
                // (the CalendarEmptyState construction).
                Image(GlyphName.addLargeCarbon.rawValue, bundle: .ui2Preview)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Geometry.addGlyph, height: Geometry.addGlyph)
                    .foregroundStyle(Token.white50)
                    .ui2Element("Add glyph")
            }
            .ui2Element("AddPlaceholderDisc")
    }

    // MARK: - B. Text block

    private var textBlock: some View {
        VStack(spacing: Token.Space.stackGap) {
            // §2 B Title: `type-hero-title`, `color-text-primary`, one line, centred.
            Text(title)
                .designTextStyle(Token.TypeStyle.heroTitle)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                // §2 B: one line on a 24 line height — SwiftUI's natural line box for a 24pt
                // font is taller, so the single line is pinned to the token's line height.
                .frame(height: Token.TypeStyle.heroTitle.lineHeight)
                .ui2Element("Title")
            // §2 B Subtitle: `type-body-sm`, `color-text-secondary`, centred, wraps
            // (§1 deviation 4: the −0.1 tracking is dropped).
            subtitle
                .designTextStyle(Token.TypeStyle.bodySm)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .ui2Element("Subtitle")
        }
        .frame(maxWidth: .infinity)
    }

    /// §2 B: the group name run in `color-text-primary`, same Regular weight (OQ-C-125-002).
    private var subtitle: Text {
        if let groupName {
            return Text(Self.groupSubtitleLead).foregroundStyle(Token.textSecondary)
                + Text(groupName + ".").foregroundStyle(Token.textPrimary)
        }
        return Text(Self.noGroupSubtitle).foregroundStyle(Token.textSecondary)
    }

    // MARK: - C. Status block

    private var statusBlock: some View {
        VStack(spacing: Token.Space.stackGap) {
            HStack(spacing: Token.Space.labelValueGap) {
                // §2 C: "ENROLLMENT STATUS" in `type-overline`, `color-text-secondary`, flexes.
                Text("ENROLLMENT STATUS")
                    .designTextStyle(Token.TypeStyle.overline)
                    .foregroundStyle(Token.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ui2Element("Status label")
                // §2 C: "N%" in `type-overline-value`, trailing, one line —
                // `color-white-50` at 0%, `color-positive` above 0%.
                Text("\(percent)%")
                    .designTextStyle(Token.TypeStyle.overlineValue)
                    .foregroundStyle(percent > 0 ? Token.positive : Token.white50)
                    .lineLimit(1)
                    .ui2Element("Percent")
            }
            // §2 C: "Label row, 11 tall" — the type's line height, pinned for the same reason.
            .frame(height: Token.TypeStyle.overline.lineHeight)
            // §2 C Bar: C-057 at `xs` / `Left` / `fillColor color-positive` (OQ-C-125-001),
            // no fill animation (§4).
            PercentBar(
                progress: progress,
                fillColor: Token.positive,
                size: .xs,
                aligned: .left
            )
            .ui2Element("Status bar")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Geometry

    private enum Geometry {
        // FLAGGED LITERAL — C-125 §2 A: hero 112×112, no token (OQ-C-125-4, owner 2026-10-24:
        // "hero 112 matches how every C-038 consumer passes its size"). Also C-038's `size`.
        static let hero: CGFloat = 112
        // FLAGGED LITERAL — C-125 §2 A: `add-large-carbon` 44×44, no token (OQ-C-125-4, owner
        // 2026-10-24: "the 44pt glyph is a one-off"). GlyphSize offers 16 / 24 / 32.
        static let addGlyph: CGFloat = 44
    }
}

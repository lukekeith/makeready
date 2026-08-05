//
//  HighlightRenderer.swift
//  MakeReady
//
//  ONE set of highlight colours, painted onto attributed text.
//
//  The four cross-app appearances come straight from the contract
//  (03-data-and-api.md §5) and are normative — web renders the same values.
//  `.editing` and `.preview` are iOS editor chrome with no web counterpart;
//  they ship today and are enumerated here so adopting surfaces stop carrying
//  private copies of them (see 06-iphone.md §The service, corrected 2026-08-04).
//
//  Painting is deliberately dumb: it takes a range and an appearance and
//  applies attributes. Deciding WHICH appearance a span has belongs to the
//  surface, which is the only thing that knows what the user is doing.
//

import UIKit

/// How a span of text is washed.
enum HighlightAppearance: Equatable, CaseIterable {

    /// A stored highlight, at rest. 03 §5: `#F4FF76` @ 0.35.
    case saved
    /// The selection the user is dragging right now. 03 §5: `#F4FF76` @ 0.55.
    case live
    /// A transient selection wash — a tapped verse, before it commits.
    /// 03 §5: white @ 0.25.
    case active
    /// A passage already used by another activity, in the Bible reader.
    /// 03 §5: `#6c47ff` @ 0.2 — the one remaining purple, and it does NOT
    /// mean "highlight".
    case used

    /// The highlight currently open in the note editor. iOS-only chrome.
    case editing
    /// The read-only preview rendering used by `ExegesisNoteEditorPage` and the
    /// activity previews. iOS-only chrome.
    case preview

    /// `nil` leaves the text's own colour alone.
    var foregroundColor: UIColor? {
        switch self {
        case .saved, .live, .active, .used:
            return nil
        case .editing, .preview:
            return .black
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .saved:   return Self.lime.withAlphaComponent(0.35)
        case .live:    return Self.lime.withAlphaComponent(0.55)
        case .active:  return UIColor.white.withAlphaComponent(0.25)
        case .used:    return Self.brandPurple.withAlphaComponent(0.2)
        case .editing: return UIColor.white
        case .preview: return UIColor.white.withAlphaComponent(0.9)
        }
    }

    /// `#F4FF76`. UIKit surfaces cannot use the SwiftUI `Color` tokens, so the
    /// components live here — this file is the single definition for every
    /// highlight surface in the app.
    private static let lime = UIColor(red: 0xF4 / 255.0, green: 0xFF / 255.0, blue: 0x76 / 255.0, alpha: 1.0)
    /// `#6c47ff`.
    private static let brandPurple = UIColor(red: 108.0 / 255.0, green: 71.0 / 255.0, blue: 255.0 / 255.0, alpha: 1.0)
}

enum HighlightRenderer {

    // MARK: - Painting

    /// Wash `range` with `appearance`. Out-of-bounds ranges are clamped, and an
    /// empty result paints nothing.
    ///
    /// Every surface used to open-code this clamp; getting it wrong renders a
    /// crash rather than a wrong colour, so it lives in one place now.
    @discardableResult
    static func paint(
        _ appearance: HighlightAppearance,
        over range: NSRange,
        in attributed: NSMutableAttributedString
    ) -> Bool {
        guard let clamped = clamp(range, to: attributed.length) else { return false }

        attributed.addAttribute(.backgroundColor, value: appearance.backgroundColor, range: clamped)
        if let foreground = appearance.foregroundColor {
            attributed.addAttribute(.foregroundColor, value: foreground, range: clamped)
        }
        return true
    }

    /// Paint a STORED highlight, honouring its style.
    ///
    /// `style: "bold"` renders as **font weight only — no background wash**, on
    /// every surface (03 §5). `boldFont` is supplied by the surface because the
    /// face differs: scripture blocks are serif, everything else is not.
    @discardableResult
    static func paintHighlight(
        style: ReadBlockSelectionStyle,
        appearance: HighlightAppearance = .saved,
        over range: NSRange,
        in attributed: NSMutableAttributedString,
        boldFont: UIFont? = nil
    ) -> Bool {
        guard let clamped = clamp(range, to: attributed.length) else { return false }

        switch style {
        case .bold:
            guard let boldFont else { return false }
            attributed.addAttribute(.font, value: boldFont, range: clamped)
            return true
        case .highlight:
            return paint(appearance, over: clamped, in: attributed)
        }
    }

    /// Convenience for the wire format, where `style` is an opaque string
    /// (03 §1.1). An unrecognised value falls back to `highlight`, matching the
    /// renderer contract in `StudyModels.ReadBlockSelection`.
    @discardableResult
    static func paintHighlight(
        style: String,
        appearance: HighlightAppearance = .saved,
        over range: NSRange,
        in attributed: NSMutableAttributedString,
        boldFont: UIFont? = nil
    ) -> Bool {
        paintHighlight(
            style: ReadBlockSelectionStyle(rawValue: style) ?? .highlight,
            appearance: appearance,
            over: range,
            in: attributed,
            boldFont: boldFont
        )
    }

    // MARK: - Composition

    /// One span to paint: where, and in which stored style.
    struct Painted: Equatable {
        let span: HighlightSpan
        let style: String

        init(span: HighlightSpan, style: String = ContentHighlight.defaultStyle) {
            self.span = span
            self.style = style
        }
    }

    /// Build the full attributed text for a highlightable block: the base verse
    /// layout, then every stored highlight, then the one being edited, then the
    /// live selection on top.
    ///
    /// **Paint order is the behaviour, not an implementation detail.** The live
    /// selection is painted LAST so it wins over whatever saved span it overlaps
    /// — otherwise dragging across an existing highlight looks like nothing is
    /// happening (monday#12668695071).
    static func attributedText(
        plainText: String,
        verseNumberRanges: [(verse: Int, range: NSRange)],
        fontSize: CGFloat,
        foregroundColor: UIColor,
        serif: Bool,
        justified: Bool,
        highlights: [Painted],
        savedAppearance: HighlightAppearance = .saved,
        editing: NSRange? = nil,
        live: NSRange? = nil
    ) -> NSMutableAttributedString {
        let attributed = BibleVerseTextLayout.baseAttributedText(
            plainText: plainText,
            verseNumberRanges: verseNumberRanges,
            fontSize: fontSize,
            foregroundColor: foregroundColor,
            paragraphStyle: BibleVerseTextLayout.paragraphStyle(justified: justified),
            serif: serif
        )

        let boldFont = BibleVerseTextLayout.serifFont(size: fontSize, weight: .bold)

        for painted in highlights {
            let isEditing = editing.map { NSEqualRanges($0, painted.span.nsRange) } ?? false
            paintHighlight(
                style: painted.style,
                appearance: isEditing ? .editing : savedAppearance,
                over: painted.span.nsRange,
                in: attributed,
                boldFont: boldFont
            )
        }

        if let live {
            paint(.live, over: live, in: attributed)
            // The lime wash is light; dark text keeps it readable.
            if let clamped = clamp(live, to: attributed.length) {
                attributed.addAttribute(.foregroundColor, value: UIColor.black, range: clamped)
            }
        }

        return attributed
    }

    // MARK: - Geometry

    /// `range` trimmed to `length`, or nil when nothing of it survives.
    static func clamp(_ range: NSRange, to length: Int) -> NSRange? {
        guard range.location != NSNotFound else { return nil }
        let start = max(0, range.location)
        let end = min(length, range.location + range.length)
        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }
}

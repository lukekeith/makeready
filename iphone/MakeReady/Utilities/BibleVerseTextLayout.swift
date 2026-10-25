//
//  BibleVerseTextLayout.swift
//  MakeReady
//
//  Shared UIKit layout helpers for scripture text. The normalized content keeps
//  verse numbers inline so selection offsets remain stable; this helper hides
//  those inline number runs and renders visible verse badges in a left rail.
//

import UIKit

enum BibleVerseTextLayout {
    /// 32px text column on both sides; verse numbers hang in the left inset.
    static let textInsets = UIEdgeInsets(top: 8, left: 32, bottom: 8, right: 32)

    /// Charter — the iOS-bundled serif used for all scripture text (print-Bible
    /// presentation modeled on Logos). Falls back to the system serif design if
    /// Charter is ever unavailable.
    static func serifFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let name: String
        switch weight {
        case .bold, .semibold, .heavy, .black: name = "Charter-Bold"
        default: name = "Charter-Roman"
        }
        if let charter = UIFont(name: name, size: size) { return charter }
        let system = UIFont.systemFont(ofSize: size, weight: weight)
        if let serifDescriptor = system.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: serifDescriptor, size: size)
        }
        return system
    }

    /// Gutter verse-number style shared by the Bible reader and exegesis views.
    static let verseNumberFont = serifFont(size: 12)
    static let verseNumberColor = UIColor(white: 1, alpha: 0.55)

    static func configureTextView(_ textView: UITextView) {
        textView.textContainerInset = textInsets
        textView.textContainer.lineFragmentPadding = 0
    }

    static func paragraphStyle(
        lineSpacing: CGFloat = 6,
        paragraphSpacing: CGFloat = 8,
        justified: Bool = true
    ) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = paragraphSpacing
        // Justified with hyphenation — matches the print-Bible layout and the
        // web client's `ThemePlayer--scripture` rendering. Non-scripture
        // content keeps natural (left) alignment.
        if justified {
            style.alignment = .justified
            style.hyphenationFactor = 0.9
        }
        return style
    }

    static func baseAttributedText(
        plainText: String,
        verseNumberRanges: [(verse: Int, range: NSRange)],
        fontSize: CGFloat,
        foregroundColor: UIColor,
        paragraphStyle: NSParagraphStyle = BibleVerseTextLayout.paragraphStyle(),
        serif: Bool = true
    ) -> NSMutableAttributedString {
        let attributed = NSMutableAttributedString(
            string: plainText,
            attributes: [
                .font: serif ? serifFont(size: fontSize) : UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: foregroundColor,
                .paragraphStyle: paragraphStyle,
            ]
        )

        hideInlineVerseNumbers(in: attributed, verseNumberRanges: verseNumberRanges)
        return attributed
    }

    static func hideInlineVerseNumbers(
        in attributed: NSMutableAttributedString,
        verseNumberRanges: [(verse: Int, range: NSRange)]
    ) {
        for entry in verseNumberRanges {
            let range = entry.range
            guard range.location >= 0,
                  range.location + range.length <= attributed.length else { continue }
            attributed.addAttribute(.foregroundColor, value: UIColor.clear, range: range)
            attributed.addAttribute(.font, value: UIFont.systemFont(ofSize: 1), range: range)
        }
    }

    @discardableResult
    static func layoutVerseBadges(
        in textView: UITextView,
        container: UIView,
        verseRanges: [VerseRange],
        target: Any?,
        action: Selector?
    ) -> [Int: UIView] {
        container.subviews.forEach { $0.removeFromSuperview() }

        let layoutManager = textView.layoutManager
        let inset = textView.textContainerInset
        var views: [Int: UIView] = [:]

        for entry in verseRanges {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: entry.range, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound else { continue }
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)

            // Plain gutter number (print-Bible style) — right-aligned so its
            // trailing edge sits a fixed gap from the text column. The view
            // is larger than the glyph to keep a comfortable tap target.
            let badge = UIView(frame: CGRect(x: 0, y: lineRect.minY + inset.top, width: textInsets.left - 8, height: 24))
            badge.backgroundColor = .clear
            badge.tag = entry.verse
            badge.isUserInteractionEnabled = action != nil

            let label = UILabel(frame: badge.bounds)
            label.text = "\(entry.verse)"
            label.font = verseNumberFont
            label.textColor = verseNumberColor
            label.textAlignment = .right
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            badge.addSubview(label)

            if let target, let action {
                badge.addGestureRecognizer(UITapGestureRecognizer(target: target, action: action))
            }

            container.addSubview(badge)
            views[entry.verse] = badge
        }

        let contentHeight = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)).height
        container.frame = CGRect(x: 0, y: 0, width: textInsets.left, height: contentHeight)
        return views
    }
}

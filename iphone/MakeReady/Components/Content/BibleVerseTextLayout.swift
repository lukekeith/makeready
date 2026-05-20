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
    static let textInsets = UIEdgeInsets(top: 8, left: 48, bottom: 8, right: 16)

    static func configureTextView(_ textView: UITextView) {
        textView.textContainerInset = textInsets
        textView.textContainer.lineFragmentPadding = 0
    }

    static func paragraphStyle(lineSpacing: CGFloat = 6, paragraphSpacing: CGFloat = 8) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = paragraphSpacing
        return style
    }

    static func baseAttributedText(
        plainText: String,
        verseNumberRanges: [(verse: Int, range: NSRange)],
        fontSize: CGFloat,
        foregroundColor: UIColor,
        paragraphStyle: NSParagraphStyle = BibleVerseTextLayout.paragraphStyle()
    ) -> NSMutableAttributedString {
        let attributed = NSMutableAttributedString(
            string: plainText,
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize),
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

            let badge = UIView(frame: CGRect(x: 16, y: lineRect.minY + inset.top, width: 24, height: 24))
            badge.layer.cornerRadius = 12
            badge.backgroundColor = UIColor(white: 1, alpha: 0.1)
            badge.tag = entry.verse
            badge.isUserInteractionEnabled = action != nil

            let label = UILabel(frame: badge.bounds)
            label.text = "\(entry.verse)"
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = UIColor(white: 1, alpha: 0.6)
            label.textAlignment = .center
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

//
//  UI2PreviewTokens.swift
//  MakeReady — UI 2.0 preview namespace
//
//  GENERATED FROM docs/ui2/design-system/tokens.md — DO NOT EDIT.
//  Regenerate with: node capture/lib/ui2-tokens.mjs
//  Rules: docs/ui2/preview-build.md §3 rule 4.
//

import SwiftUI

/// A designed text style: SwiftUI has no line-height, so the leading is applied
/// as lineSpacing (lineHeight − size) by the `ui2TextStyle` modifier.
struct UI2TextStyle {
    let weight: Font.Weight
    let size: CGFloat
    let lineHeight: CGFloat?
    let tracking: CGFloat

    var font: Font { .system(size: size, weight: weight) }
    var lineSpacing: CGFloat { max((lineHeight ?? size) - size, 0) }
}

extension View {
    func ui2TextStyle(_ style: UI2TextStyle) -> some View {
        font(style.font).tracking(style.tracking).lineSpacing(style.lineSpacing)
    }
}

enum UI2Token {
    static let layoutBackground = Color(red: 0.0118, green: 0.0157, blue: 0.0196, opacity: 1)
    static let layoutBorder = Color(red: 0.1843, green: 0.2118, blue: 0.2235, opacity: 1)
    static let cardBackground = Color(red: 0.1216, green: 0.1294, blue: 0.1412, opacity: 1)
    static let cardBorder = Color(red: 0.1843, green: 0.2118, blue: 0.2275, opacity: 1)
    static let accent = Color(red: 0.4235, green: 0.2784, blue: 1.0, opacity: 1)
    static let accent50 = Color(red: 0.4235, green: 0.2784, blue: 1.0, opacity: 0.5)
    static let accent20 = Color(red: 0.4235, green: 0.2784, blue: 1.0, opacity: 0.2)
    static let positive = Color(red: 0.4235, green: 1.0, blue: 0.451, opacity: 1)
    static let negative = Color(red: 1.0, green: 0.2784, blue: 0.349, opacity: 1)
    static let highlight = Color(red: 0.9569, green: 1.0, blue: 0.4627, opacity: 1)
    static let brandHighlight = Color(red: 0.7725, green: 1.0, blue: 0.9725, opacity: 1)
    static let textPrimary = Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1)
    static let textSecondary = Color(red: 0.5216, green: 0.5922, blue: 0.6196, opacity: 1)
    static let navText = Color(red: 0.5569, green: 0.6275, blue: 0.6549, opacity: 1)
    static let white50 = Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.5)
    static let white20 = Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.2)
    static let white10 = Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.1)
    static let neutral600 = Color(red: 0.2902, green: 0.3333, blue: 0.3961, opacity: 1)
    static let inputPlaceholder = Color(red: 0.3216, green: 0.3647, blue: 0.3882, opacity: 1)
    static let inputValue = Color(red: 0.5569, green: 0.6275, blue: 0.6549, opacity: 1)
    static let white70 = Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.7)
    static let error = Color(red: 0.9843, green: 0.1725, blue: 0.2118, opacity: 1)
    static let brandPrimaryBg = Color(red: 0.2706, green: 0.1333, blue: 0.8275, opacity: 1)
    static let neutral800 = Color(red: 0.1176, green: 0.1608, blue: 0.2235, opacity: 1)
    static let neutral200 = Color(red: 0.898, green: 0.9059, blue: 0.9216, opacity: 1)
    static let neutral100 = Color(red: 0.9294, green: 0.9373, blue: 0.949, opacity: 1)
    static let navBorder = Color(red: 0.3216, green: 0.3647, blue: 0.3765, opacity: 1)
    static let navBorderActive = Color(red: 0.5529, green: 0.6235, blue: 0.6549, opacity: 1)
    static let navTabBackground = Color(red: 0.1098, green: 0.1294, blue: 0.1412, opacity: 1)
    static let backgroundAlt = Color(red: 0.051, green: 0.0627, blue: 0.102, opacity: 1)
    static let modalBackground = Color(red: 0.1216, green: 0.1294, blue: 0.1412, opacity: 1)
    static let black = Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1)
    static let transparent = Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0)

    // NOT `Type`: `UI2Token.Type` is Swift's metatype syntax for the enum itself.
    enum TypeStyle {
        static let calloutBold = UI2TextStyle(weight: .semibold, size: 16, lineHeight: 21, tracking: -0.32)
        static let bodyLg = UI2TextStyle(weight: .regular, size: 17, lineHeight: 22, tracking: 0)
        static let footnote = UI2TextStyle(weight: .regular, size: 13, lineHeight: 18, tracking: 0)
        static let titleCard = UI2TextStyle(weight: .bold, size: 14, lineHeight: 20, tracking: 0)
        static let valueEmphasis = UI2TextStyle(weight: .bold, size: 18, lineHeight: 24, tracking: 0)
        static let caption = UI2TextStyle(weight: .regular, size: 12, lineHeight: 14, tracking: 0)
        static let captionBold = UI2TextStyle(weight: .bold, size: 12, lineHeight: nil, tracking: 0)
        static let captionSemibold = UI2TextStyle(weight: .semibold, size: 12, lineHeight: nil, tracking: 0)
        static let body = UI2TextStyle(weight: .regular, size: 14, lineHeight: nil, tracking: 0)
        static let sectionTitle = UI2TextStyle(weight: .semibold, size: 18, lineHeight: 24, tracking: 0)
        static let subtitleSemibold = UI2TextStyle(weight: .semibold, size: 14, lineHeight: 20, tracking: 0)
        static let valueHero = UI2TextStyle(weight: .regular, size: 24, lineHeight: 32, tracking: 0)
        static let actionItem = UI2TextStyle(weight: .regular, size: 18, lineHeight: 24, tracking: 0)
        static let navLabel = UI2TextStyle(weight: .bold, size: 14, lineHeight: 16, tracking: 0)
        static let input = UI2TextStyle(weight: .regular, size: 14, lineHeight: 24, tracking: 0)
        static let pageTitle = UI2TextStyle(weight: .regular, size: 14, lineHeight: 20, tracking: 0)
        static let navAction = UI2TextStyle(weight: .regular, size: 14, lineHeight: 24, tracking: 0.56)
    }

    enum Space {
        static let pageMargin: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let elementGap: CGFloat = 8
        static let sectionGap: CGFloat = 32
        static let metaGap: CGFloat = 4
        static let chipGap: CGFloat = 2
        static let rowGap: CGFloat = 24
    }

    enum Radius {
        static let cardSm: CGFloat = 4
        static let card: CGFloat = 8
        static let modal: CGFloat = 16
        static let bar: CGFloat = 2
    }
}

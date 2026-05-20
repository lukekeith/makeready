//
//  Colors.swift
//  MakeReady
//
//  Centralized color definitions for the app
//

import SwiftUI
import UIKit

// MARK: - Color Extensions

extension Color {

    // MARK: - System Color Overrides

    /// Override system purple with brand purple - #6C47FF
    static let purple = Color(hex: "#6C47FF")

    // MARK: - Brand Colors

    /// Primary brand purple - #6c47ff (same as .purple)
    static let brandPrimary = purple

    /// Brand purple opacity variants
    static let brandPrimary80 = brandPrimary.opacity(0.8)
    static let brandPrimary70 = brandPrimary.opacity(0.7)
    static let brandPrimary60 = brandPrimary.opacity(0.6)
    static let brandPrimary40 = brandPrimary.opacity(0.4)
    static let brandPrimary30 = brandPrimary.opacity(0.3)
    static let brandPrimary20 = brandPrimary.opacity(0.2)

    // MARK: - Background Colors

    /// Main app background - #0d101a (dark navy)
    static let appBackground = Color(hex: "#0d101a")

    /// Alternative dark background - #0a0a0f (near black)
    static let backgroundDark = Color(hex: "#0a0a0f")

    /// Dark purple background for pending/new states - #201B48
    static let backgroundPurple = Color(hex: "#201B48")

    // MARK: - Surface Colors (Cards, Containers)

    /// Card background - #333541
    static let cardBackground = Color(hex: "#252936")

    /// Icon container background - #485470 at 50%
    static let iconContainerBackground = Color(hex: "#485470").opacity(0.5)

    /// Elevated surface - #252936
    static let surfaceElevated = Color(hex: "#252936")

    // MARK: - Accent Colors

    /// Accent blue - #5680ff (links, highlights)
    static let accentBlue = Color(hex: "#5680ff")

    // MARK: - Semantic Colors

    /// Warning yellow - #F4FF76
    static let warning = Color(hex: "#F4FF76")
    static let warningBackground = warning.opacity(0.2)

    /// Error/destructive red - #FF4759
    static let error = Color(hex: "#FF4759")
    static let errorBackground = error.opacity(0.2)

    /// Destructive action red - #df1439
    static let destructive = Color(hex: "#df1439")

    /// Success green (for future use)
    static let success = Color(hex: "#57DB5D")

    /// Bible highlight yellow - #F4FF76 at 50% opacity
    static let highlightYellow = Color(hex: "#F4FF76").opacity(0.5)

    // MARK: - White Opacity Variants

    static let white10 = Color.white.opacity(0.1)
    static let white20 = Color.white.opacity(0.2)
    static let white30 = Color.white.opacity(0.3)
    static let white50 = Color.white.opacity(0.5)
    static let white70 = Color.white.opacity(0.7)
    
    // MODAL:
    
    static let sectionBackground = Color(hex: "#191C25")

    // MARK: - Legacy Aliases (for backward compatibility)

    /// @available(*, deprecated, renamed: "accentBlue")
    static let sentRecently = accentBlue

    // MARK: - Hex Initializer

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Screen Utilities

/// Screen utilities that avoid deprecated UIScreen.main.
/// Intentionally NOT on UIScreen to prevent triggering deprecation warnings.
@MainActor
enum Screen {
    static var bounds: CGRect {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds
            ?? CGRect(x: 0, y: 0, width: 393, height: 852)
    }

    static var scale: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.scale ?? 3.0
    }
}

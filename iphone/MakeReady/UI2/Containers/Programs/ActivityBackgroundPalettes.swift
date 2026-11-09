import Foundation

/// text-activity-v2 D4 (superseded 2026-11-08, round 2): the curated palettes a new activity's blob gradient
/// is drawn from — one dark base that reads under white text (≥ 4.5:1) and vivid blob colours (≥ 3:1 against
/// white, WCAG AA for the canvas's large text; HSB saturation ≥ 0.55), so the page reads as a colourful gradient.
/// The owner tunes these after the walk; documents keep their colours, never a palette id (D13).
enum ActivityBackgroundPalettes {
    static let all: [[String]] = [
        ["#1A1446", "#6C3BFF", "#E0306F", "#2F7BE8", "#B24BE0"], // midnight
        ["#062F3A", "#00897B", "#1E88E5", "#7B3FE4", "#D81B8C"], // lagoon
        ["#3A0A12", "#E63946", "#F2542D", "#C2185B", "#8E24AA"], // ember
        ["#0B2A1A", "#2E8B57", "#00897B", "#689F38", "#1E88E5"], // forest
        ["#2A0A33", "#9C27B0", "#E91E63", "#5E35B1", "#F4511E"], // plum
        ["#061A3A", "#1E6FE0", "#0096C7", "#6A3DE8", "#E0407A"], // ocean
        ["#3A0A2A", "#FF5A36", "#E0306F", "#9C27B0", "#EF6C00"], // sunset
        ["#071F2E", "#00A884", "#3D5AFE", "#AA00FF", "#0096C7"], // aurora
        ["#33061C", "#D81B60", "#8E24AA", "#F4511E", "#5E35B1"], // berry
        ["#2A1A05", "#E65100", "#E53935", "#A88A00", "#43A047"], // citrus
        ["#1A1030", "#7E57C2", "#EC407A", "#3F51B5", "#E8590C"], // dusk
        ["#05302A", "#00897B", "#F4511E", "#D81B60", "#1E88E5"]  // tropic
    ]

    /// D4: the base's minimum contrast with white, and the blob colours' (large text, WCAG AA).
    static let baseContrast = 4.5
    static let blobContrast = 3.0
    /// D4: a blob colour is vivid — HSB saturation at least this.
    static let blobSaturation = 0.55

    /// WCAG relative luminance of `#RRGGBB` (0 black … 1 white); an unreadable hex counts as black.
    static func luminance(_ hex: String) -> Double {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return 0 }
        func channel(_ shift: UInt32) -> Double {
            let c = Double((value >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    /// HSB saturation of `#RRGGBB`, 0–1 (0 for an unreadable hex).
    static func saturation(_ hex: String) -> Double {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return 0 }
        let channels = [16, 8, 0].map { Double((value >> UInt32($0)) & 0xFF) / 255 }
        guard let high = channels.max(), let low = channels.min(), high > 0 else { return 0 }
        return (high - low) / high
    }

    /// The contrast ratio of white text over `hex`.
    static func contrastWithWhite(_ hex: String) -> Double {
        1.05 / (luminance(hex) + 0.05)
    }

    /// The palette's darkest colour (lowest luminance) — a gradient's `base` (D3).
    static func darkest(_ palette: [String]) -> String {
        palette.min { luminance($0) < luminance($1) } ?? "#000000"
    }
}

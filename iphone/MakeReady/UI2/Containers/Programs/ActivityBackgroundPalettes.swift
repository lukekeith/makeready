import Foundation

/// text-activity-v2 D4: the curated palettes a new activity's blob gradient is drawn from.
/// Every colour reads under white text: ≥ 4.5:1 against `#FFFFFF` (WCAG), so they are deep tones.
/// The owner tunes these after the walk; documents keep their colours, never a palette id (D13).
enum ActivityBackgroundPalettes {
    static let all: [[String]] = [
        ["#1B1F4A", "#3B3F9E", "#5B3E96", "#2E5C8A", "#7A2E8E"], // midnight
        ["#0B3440", "#0F6B6E", "#1F5F8B", "#13807A", "#2A4E7A"], // lagoon
        ["#3A0F1A", "#A3262E", "#B4442A", "#8C1F4F", "#9A3B12"], // ember
        ["#0F2E1F", "#1E6B3A", "#2F7A55", "#4A6B1E", "#14625E"], // forest
        ["#2A0F33", "#6B2380", "#8E2C6E", "#4B2A8C", "#A0285A"], // plum
        ["#0A1F3D", "#1A4C8C", "#2563A8", "#0F6E8C", "#3A3F9E"], // ocean
        ["#3A1030", "#B03A4A", "#A8462E", "#7A2F7A", "#C0392B"], // sunset
        ["#0D2233", "#14736B", "#3A4FA0", "#6A2E8C", "#1C6B8C"], // aurora
        ["#33071F", "#9C1F55", "#7A1F7A", "#B0284A", "#5A2A9C"], // berry
        ["#1A2410", "#4F6B1A", "#2E6B3F", "#6B5A12", "#1F5E4A"], // moss
        ["#1F1433", "#4A3A8C", "#7A3A7A", "#2E4A8C", "#8C3A5A"], // dusk
        ["#2E1408", "#8C3A12", "#A0461F", "#7A2E1F", "#6B4A12"]  // copper
    ]

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

    /// The contrast ratio of white text over `hex`.
    static func contrastWithWhite(_ hex: String) -> Double {
        1.05 / (luminance(hex) + 0.05)
    }

    /// The palette's darkest colour (lowest luminance) — a gradient's `base` (D3).
    static func darkest(_ palette: [String]) -> String {
        palette.min { luminance($0) < luminance($1) } ?? "#000000"
    }
}

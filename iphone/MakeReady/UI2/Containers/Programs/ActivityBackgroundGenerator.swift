import Foundation

/// text-activity-v2 D3: makes a new activity's blob gradient. Pure: the same palette and RNG state
/// always give the same gradient, so tests inject a seeded generator.
enum ActivityBackgroundGenerator {
    static let blobCount = 4

    /// `base` = the palette's darkest colour; 4 blobs coloured from the palette's other colours
    /// (cycling when it has fewer than 4), `x` 0–1, `y` 0–1.6, `r` 0.45–0.8 (fractions of the page width, D2).
    static func make<R: RandomNumberGenerator>(palette: [String], rng: inout R) -> ActivityBackground.Gradient {
        let base = ActivityBackgroundPalettes.darkest(palette)
        var others = palette.filter { $0 != base }
        if others.isEmpty { others = [base] }
        let blobs = (0..<blobCount).map { index in
            ActivityBackground.Gradient.Blob(
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...1.6, using: &rng),
                r: Double.random(in: 0.45...0.8, using: &rng),
                color: others[index % others.count]
            )
        }
        return ActivityBackground.Gradient(base: base, blobs: blobs)
    }

    /// One of the curated palettes, picked at random (D3).
    static func randomPalette<R: RandomNumberGenerator>(rng: inout R) -> [String] {
        ActivityBackgroundPalettes.all.randomElement(using: &rng) ?? ActivityBackgroundPalettes.all[0]
    }
}

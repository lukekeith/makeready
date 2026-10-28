import UIKit

/// cover-image-sizes (owner 2026-10-28): a list never loads a full cover. Every cover upload
/// writes a ladder beside the ≤1200px file `coverImageUrl` names — `<name>-md.<ext>` (400px) and
/// `<name>-thumb.<ext>` (150px) — so a list asks for the 400px sibling. A cover with no ladder (a
/// legacy upload, an outside URL) falls back to its own file decoded at the list width, so the
/// list's key always holds a list-sized image. Pages keep `coverImageUrl`. Every load goes
/// through `UI2ImageLoader`'s fetch (ImageCache: memory → disk → network).
enum CoverImageLoader {
    /// The list copy's width: the ladder's `-md` rung.
    static let listWidth: CGFloat = 400

    /// The list-size URL for a cover — its `-md` sibling when the URL names an image file, else
    /// the URL itself; "" stays "".
    static func listURL(_ cover: String) -> String {
        guard !cover.isEmpty, let url = URL(string: cover),
              ["jpeg", "jpg", "png", "webp"].contains(url.pathExtension.lowercased()),
              !url.deletingPathExtension().lastPathComponent.hasSuffix("-md") else { return cover }
        return cover.mediumImageUrl
    }

    /// Each cover's list URL when it is already in Ui2ImageCache, else "" (the component's empty
    /// look until it lands).
    @MainActor
    static func cachedListURLs(_ covers: [String]) -> [String] {
        covers.map { cover in
            let key = listURL(cover)
            guard let url = URL(string: key), Ui2ImageCache.shared.image(for: url) != nil else { return "" }
            return key
        }
    }

    /// Puts each cover's list copy in Ui2ImageCache under its list URL: the `-md` file, else the
    /// cover itself decoded at `listWidth`. A cover that loads neither way keeps the empty look.
    /// Returns whether any landed.
    @MainActor
    static func seedList(_ covers: [String], fetch: UI2ImageLoader.Fetch = UI2ImageLoader.live,
                         state: AppState? = nil) async -> Bool {
        var seeded = false
        for cover in covers where !cover.isEmpty {
            let key = listURL(cover)
            guard let keyURL = URL(string: key), keyURL.scheme?.hasPrefix("http") == true,
                  Ui2ImageCache.shared.image(for: keyURL) == nil else { continue }
            do {
                Ui2ImageCache.shared.seed(try await fetch(keyURL, nil), for: keyURL)
                seeded = true
            } catch {
                if UI2ImageLoader.isCancellation(error) { return seeded }
                guard key != cover, let original = URL(string: cover) else {
                    (state ?? .shared).recordError(error, context: "CoverImageLoader.seedList", surface: false)
                    continue
                }
                do {
                    Ui2ImageCache.shared.seed(try await fetch(original, listWidth), for: keyURL)
                    seeded = true
                } catch {
                    if UI2ImageLoader.isCancellation(error) { return seeded }
                    (state ?? .shared).recordError(error, context: "CoverImageLoader.seedList", surface: false)
                }
            }
        }
        return seeded
    }
}

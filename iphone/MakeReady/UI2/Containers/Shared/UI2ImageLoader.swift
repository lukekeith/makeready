import UIKit

/// ui2-image-cache (owner 2026-10-28: "state management should be solving this so we aren't
/// fetching those things all the time"): the one way a UI2 container loads a remote image. It
/// goes through the app's `ImageCache` — memory → disk → network, one shared download for
/// concurrent asks, the bytes kept on disk across launches — and mirrors the result into
/// `Ui2ImageCache`, the synchronous map the d2m screens read in their first layout pass.
enum UI2ImageLoader {
    /// One load: the image at a URL, decoded to at most `maxPixelSize` on its longest edge (nil =
    /// full size). Throws when there is no such image (tests stub it).
    typealias Fetch = @Sendable (URL, CGFloat?) async throws -> UIImage

    static let live: Fetch = { url, maxPixelSize in
        try await ImageCache.shared.fetch(url: url, maxPixelSize: maxPixelSize)
    }

    /// Puts each http(s) image in Ui2ImageCache under its own URL, skipping any already there. An
    /// image that will not load keeps the component's empty look; the failure is recorded,
    /// console-only. Returns whether any landed.
    @MainActor
    static func seed(_ urls: [String], context: String, fetch: Fetch = live, state: AppState? = nil) async -> Bool {
        var seeded = false
        for raw in urls {
            guard let url = URL(string: raw), url.scheme?.hasPrefix("http") == true,
                  Ui2ImageCache.shared.image(for: url) == nil else { continue }
            do {
                Ui2ImageCache.shared.seed(try await fetch(url, nil), for: url)
                seeded = true
            } catch {
                if isCancellation(error) { return seeded }
                (state ?? .shared).recordError(error, context: "\(context).seedImages", surface: false)
            }
        }
        return seeded
    }

    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}

import UIKit

/// cover-image-sizes (owner 2026-10-28): a list never loads a full cover. Every cover upload
/// writes a ladder beside the ≤1200px file `coverImageUrl` names — `<name>-md.<ext>` (400px) and
/// `<name>-thumb.<ext>` (150px) — so a list asks for the 400px sibling. A cover with no ladder (a
/// legacy upload, an outside URL) falls back to its own file, cut down to the list width before it
/// is cached, so the list's key always holds a list-sized image. Pages keep `coverImageUrl`.
enum CoverImageLoader {
    /// The list copy's width: the ladder's `-md` rung.
    static let listWidth: CGFloat = 400

    /// One fetch: the body and the HTTP status (tests stub it).
    typealias Fetch = @Sendable (URL) async throws -> (Data, Int)

    static let liveFetch: Fetch = { url in
        let (data, response) = try await URLSession.shared.data(from: url)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 200)
    }

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
    /// cover itself cut down to `listWidth`. A cover that loads neither way keeps the empty look.
    /// Returns whether any landed.
    @MainActor
    static func seedList(_ covers: [String], fetch: Fetch = liveFetch, state: AppState? = nil) async -> Bool {
        var seeded = false
        for cover in covers where !cover.isEmpty {
            let key = listURL(cover)
            guard let keyURL = URL(string: key), keyURL.scheme?.hasPrefix("http") == true,
                  Ui2ImageCache.shared.image(for: keyURL) == nil else { continue }
            do {
                if let image = try await load(keyURL, fetch: fetch) {
                    Ui2ImageCache.shared.seed(image, for: keyURL)
                    seeded = true
                } else if key != cover, let original = URL(string: cover), let image = try await load(original, fetch: fetch) {
                    Ui2ImageCache.shared.seed(downsized(image, toWidth: listWidth), for: keyURL)
                    seeded = true
                }
            } catch {
                if error is CancellationError || (error as? URLError)?.code == .cancelled { return seeded }
                (state ?? .shared).recordError(error, context: "CoverImageLoader.seedList", surface: false)
            }
        }
        return seeded
    }

    /// The image at `url`, or nil when the server has no such file (any non-2xx) or it isn't an image.
    private static func load(_ url: URL, fetch: Fetch) async throws -> UIImage? {
        let (data, status) = try await fetch(url)
        guard (200..<300).contains(status) else { return nil }
        return UIImage(data: data)
    }

    /// `image` no wider than `width` points-as-pixels (scale 1), aspect kept; never enlarged.
    static func downsized(_ image: UIImage, toWidth width: CGFloat) -> UIImage {
        let pixels = pixelSize(image)
        guard pixels.width > width else { return image }
        let size = CGSize(width: width, height: (pixels.height * width / pixels.width).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// The bitmap's size in pixels (the CGImage's; else the point size).
    static func pixelSize(_ image: UIImage) -> CGSize {
        guard let cg = image.cgImage else { return image.size }
        return CGSize(width: cg.width, height: cg.height)
    }
}

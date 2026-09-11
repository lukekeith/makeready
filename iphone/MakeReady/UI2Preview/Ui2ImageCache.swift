//
//  Ui2ImageCache.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Cache-first image resolution for preview views. PREVIEW ONLY: referenced by no screen,
//  route, tab or flag (docs/ui2/preview-build.md §3 rule 1).
//
//  Why it exists. A snapshot capture renders in ONE synchronous layout pass, so an
//  `AsyncImage`'s network task can never finish inside it and the image box comes out empty
//  — which is exactly what C-033's avatar showed. The 1.0 harness already solves this the
//  same way: `CaptureEnvironment.setupCaptureState` fetches a component's remote images
//  synchronously and seeds `ImageCache.shared` before the pass, and `CachedCardImage` reads
//  cache-first. `UI2Preview` imports SwiftUI and nothing else (preview-build.md §2), so it
//  cannot reach `MakeReady.ImageCache` and carries its own one-page version of the idea.
//
//  It is not a network layer and does not fetch: something else puts an image in, a view
//  reads it out. In the capture that "something" is the ViewRegistry case; in the app it
//  would be whatever image pipeline `ui2-shell` promotes this module into.
//

import SwiftUI

/// A synchronous, in-memory URL → image map that a view can read during its own layout pass.
///
/// `@MainActor` because both sides of it are: a SwiftUI `body` and the capture harness's
/// `buildCaptureView` are main-actor isolated, so no synchronisation is needed beyond that.
@MainActor
final class Ui2ImageCache {

    static let shared = Ui2ImageCache()

    private var images: [URL: UIImage] = [:]

    private init() {}

    func seed(_ image: UIImage, for url: URL) {
        images[url] = image
    }

    func image(for url: URL) -> UIImage? {
        images[url]
    }
}

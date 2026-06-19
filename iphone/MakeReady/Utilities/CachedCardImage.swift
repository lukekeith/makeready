//
//  CachedCardImage.swift
//  MakeReady
//
//  Reusable rectangular card image with variant fallback and persistent caching.
//  Tries the variant URL first (e.g. medium); on failure falls back to the original.
//

import SwiftUI

struct CachedCardImage<Placeholder: View, Fallback: View>: View {
    let url: String?
    let fallbackUrl: String?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let contentMode: ContentMode
    let clipCircle: Bool
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let fallback: () -> Fallback

    @State private var image: UIImage?
    @State private var phase: LoadPhase = .idle
    @State private var loadedURL: String?

    private enum LoadPhase {
        case idle, loading, loaded, failed
    }

    init(
        url: String?,
        fallbackUrl: String? = nil,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat = 8,
        contentMode: ContentMode = .fill,
        clipCircle: Bool = false,
        @ViewBuilder placeholder: @escaping () -> Placeholder = { CardLoadingPlaceholder() },
        @ViewBuilder fallback: @escaping () -> Fallback = { Color.iconContainerBackground }
    ) {
        self.url = url
        self.fallbackUrl = fallbackUrl
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
        self.clipCircle = clipCircle
        self.placeholder = placeholder
        self.fallback = fallback

        // Cache-first: if the image is already in the memory cache, render it
        // from the very first frame so it moves WITH its container (e.g. a card
        // sliding in a modal panel transition) instead of popping in after the
        // .task load — same technique as CachedAsyncImage.
        let seeded: UIImage? = {
            if let s = url, let u = URL(string: s),
               let cached = ImageCache.shared.cachedImage(for: u) { return cached }
            if let s = fallbackUrl, let u = URL(string: s),
               let cached = ImageCache.shared.cachedImage(for: u) { return cached }
            return nil
        }()
        if let seeded {
            _image = State(initialValue: seeded)
            _phase = State(initialValue: .loaded)
            _loadedURL = State(initialValue: url)
        }
    }

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                placeholder()
            case .loaded:
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
                    fallback()
                }
            case .failed:
                fallback()
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .if(clipCircle) { $0.clipShape(Circle()) }
        .if(!clipCircle) { $0.cornerRadius(cornerRadius) }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        // Already have the image for this URL (seeded from cache in init, or
        // loaded earlier). Don't reset to .loading and flash the placeholder —
        // that would interrupt a container transition (e.g. a sliding modal
        // panel), making the image look like it isn't moving with the card.
        if image != nil, loadedURL == url { return }

        guard let urlString = url, let primary = URL(string: urlString) else {
            phase = .failed
            return
        }

        phase = .loading

        // Try primary (variant) URL
        if let img = try? await ImageCache.shared.fetch(url: primary) {
            image = img
            loadedURL = url
            phase = .loaded
            return
        }

        // Try fallback (original) URL
        if let fbString = fallbackUrl, let fbURL = URL(string: fbString) {
            if let img = try? await ImageCache.shared.fetch(url: fbURL) {
                image = img
                loadedURL = url
                phase = .loaded
                return
            }
        }

        phase = .failed
    }
}

// MARK: - CachedBackgroundImage (fills available space, no fixed frame)

/// Cache-backed background image that fills its container. Used for card backgrounds at low opacity.
struct CachedBackgroundImage: View {
    let url: String?
    let fallbackUrl: String?

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        if let urlString = url, let primary = URL(string: urlString),
           let img = try? await ImageCache.shared.fetch(url: primary) {
            image = img
            return
        }
        if let fbString = fallbackUrl, let fbURL = URL(string: fbString),
           let img = try? await ImageCache.shared.fetch(url: fbURL) {
            image = img
        }
    }
}

// MARK: - Conditional modifier helper

private extension View {
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

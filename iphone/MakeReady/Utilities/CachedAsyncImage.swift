//
//  CachedAsyncImage.swift
//  MakeReady
//
//  Memory-cached async image that doesn't trigger reloads during animations.
//
//  Problem:
//  Standard AsyncImage can cause jitter when used inside animated containers
//  because SwiftUI may re-trigger the loading phase during view updates.
//  This is especially noticeable in headers and menus that slide in/out.
//
//  Solution:
//  Cache the loaded UIImage in @State so it persists across view updates.
//  Only reload if the URL actually changes.
//
//  Usage:
//  ```swift
//  CachedAsyncImage(url: user.avatarURL, size: 80)
//  CachedAsyncImage(url: user.avatarURL, size: 40, fallbackInitials: "JD")
//  ```
//

import SwiftUI

/// Memory-cached async image that doesn't reload during animations
struct CachedAsyncImage: View {
    let url: URL?
    let size: CGFloat
    let fallbackInitials: String?
    let fallbackIcon: String?

    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    @State private var lastLoadedURL: URL?

    init(
        url: URL?,
        size: CGFloat,
        fallbackInitials: String? = nil,
        fallbackIcon: String? = "person.fill"
    ) {
        self.url = url
        self.size = size
        self.fallbackInitials = fallbackInitials
        self.fallbackIcon = fallbackIcon

        // Pre-populate from memory cache so the image is present from the first render.
        // This prevents the image appearing mid-animation when the view is inside
        // an animated container (e.g., slide-up menu).
        if let url = url, let cached = ImageCache.shared.cachedImage(for: url) {
            _cachedImage = State(initialValue: cached)
            _lastLoadedURL = State(initialValue: url)
        }
    }

    /// Convenience initializer with string URL
    init(
        urlString: String?,
        size: CGFloat,
        fallbackInitials: String? = nil,
        fallbackIcon: String? = "person.fill"
    ) {
        let resolvedURL = urlString.flatMap { URL(string: $0) }
        self.url = resolvedURL
        self.size = size
        self.fallbackInitials = fallbackInitials
        self.fallbackIcon = fallbackIcon

        if let url = resolvedURL, let cached = ImageCache.shared.cachedImage(for: url) {
            _cachedImage = State(initialValue: cached)
            _lastLoadedURL = State(initialValue: url)
        }
    }

    var body: some View {
        Group {
            if let image = cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url) {
            await loadImageIfNeeded()
        }
    }

    @ViewBuilder
    private var fallbackView: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                if let initials = fallbackInitials {
                    Text(initials.prefix(2).uppercased())
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(.white)
                } else if let icon = fallbackIcon {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
    }

    private func loadImageIfNeeded() async {
        // Skip if already loaded this URL
        guard let url = url, url != lastLoadedURL else { return }

        // Skip if we already have a cached image for the current URL
        if cachedImage != nil && lastLoadedURL == url { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let image = try await ImageCache.shared.fetch(url: url)
            await MainActor.run {
                cachedImage = image
                lastLoadedURL = url
            }
        } catch {
            // Silently handle network errors - fallback view will show
            NSLog("CachedAsyncImage: Failed to load \(url): \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 24) {
            // With URL
            CachedAsyncImage(
                url: URL(string: "https://picsum.photos/200"),
                size: 80
            )

            // With initials fallback
            CachedAsyncImage(
                url: nil,
                size: 60,
                fallbackInitials: "JD"
            )

            // With icon fallback
            CachedAsyncImage(
                url: nil,
                size: 40,
                fallbackIcon: "person.fill"
            )
        }
    }
}

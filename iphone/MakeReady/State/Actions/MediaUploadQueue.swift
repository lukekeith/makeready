import Foundation
import Observation
import UIKit

/// media-library D13: one item the leader picked on the Media page.
enum PickedMedia {
    case photo(UIImage, data: Data?)
    case video(URL)
}

/// media-library D13: the Media page's uploads, run one after another by AppState rather than by the
/// view, so leaving Media never cancels them. A photo that lands is inserted into
/// `AppState.mediaLibrary` straight away; a video shows on the next load (its row is pending until
/// Cloudflare finishes). Each failure surfaces on its own and the rest carry on. No progress UI (v1).
@MainActor
@Observable
final class MediaUploadQueue {
    /// Uploads not finished yet (queued or running).
    private(set) var pending = 0
    @ObservationIgnored private var tail: Task<Void, Never>?

    /// Queues `items` for `orgId`. `uploader` stamps the locally inserted photos (the signed-in leader).
    func enqueue(_ items: [PickedMedia], orgId: String, uploader: MediaUploader?, state: AppState,
                 actions: MediaActions? = nil, now: @escaping () -> Date = Date.init) {
        guard !items.isEmpty else { return }
        pending += items.count
        let previous = tail
        tail = Task { @MainActor [weak self] in
            await previous?.value
            let actions = actions ?? MediaActions(state: state)
            for item in items {
                await Self.upload(item, orgId: orgId, uploader: uploader, state: state, actions: actions, now: now)
                self?.pending -= 1
            }
        }
    }

    /// Waits for everything queued so far (tests).
    func drain() async { await tail?.value }

    /// Sign-out: drop what hasn't started.
    func cancelAll() {
        tail?.cancel()
        tail = nil
        pending = 0
    }

    private static func upload(_ item: PickedMedia, orgId: String, uploader: MediaUploader?, state: AppState,
                               actions: MediaActions, now: () -> Date) async {
        do {
            switch item {
            case .photo(let image, let data):
                let takenAt = data.flatMap { CaptureDate.read(from: $0) }
                let title = title("Photo", takenAt: takenAt)
                let uploaded = try await actions.uploadPhoto(image: image, title: title, sourceData: data, orgId: orgId)
                let stamp = now()
                state.mediaLibrary.upsert(MediaLibraryItem(
                    id: uploaded.id, title: title, description: nil, url: uploaded.url, type: "photo",
                    mimeType: "image/jpeg", fileSize: nil, thumbnailUrl: uploaded.thumbnailUrl,
                    uploadStatus: "ready", duration: nil, tags: [], usageCount: 0, uploader: uploader, video: nil,
                    createdAt: stamp, updatedAt: stamp, takenAt: takenAt.flatMap(Self.parse),
                    organizationId: orgId, isMakeReady: false))
            case .video(let url):
                try await actions.uploadVideo(fileURL: url, title: "Video", orgId: orgId)
            }
        } catch {
            if Task.isCancelled { return }
            state.recordError(error, context: "MediaUploadQueue.upload", surface: true)
        }
    }

    /// D19: "Photo" / "Video", plus the capture day when the file carries one ("Photo · Oct 3, 2026").
    static func title(_ kind: String, takenAt: String?) -> String {
        guard let date = takenAt.flatMap(parse) else { return kind }
        return "\(kind) · \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    private static func parse(_ iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso) ?? { f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f.date(from: iso) }()
    }
}

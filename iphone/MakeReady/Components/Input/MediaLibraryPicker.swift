//
//  MediaLibraryPicker.swift
//  MakeReady
//
//  Modal picker that lets the user select a photo from their organization's
//  media library (already-uploaded images). Wraps the existing
//  MediaLibraryGrid; presented via OverlayManager.presentModal from the
//  read-block background picker.
//
//  Filters to type=photo only and dismisses on selection via the dismissOverlay
//  environment action.
//

import SwiftUI

struct MediaLibraryPicker: View {
    /// Called with the chosen media item after the modal dismisses.
    var onSelect: (MediaLibraryItem) -> Void

    @Environment(\.dismissOverlay) private var dismissOverlay
    private var state: AppState { AppState.shared }

    private var photoItems: [MediaLibraryItem] {
        state.orderedMedia
            .filter { $0.type == "photo" && $0.isReady }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageTitle.iconTitle(
                title: "Media Library",
                icon: "xmark",
                onIconTap: { dismissOverlay?() }
            )

            if photoItems.isEmpty {
                emptyState
            } else {
                MediaLibraryGrid(
                    items: photoItems,
                    topInset: 8,
                    onItemSelected: { item, _, _ in
                        let chosen = item
                        dismissOverlay?()
                        // Defer the callback until the dismiss animation
                        // settles so the parent can present its own follow-up
                        // overlay (e.g. an upload progress) without z-index
                        // conflicts.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            onSelect(chosen)
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .task {
            do {
                try await MediaActions().loadLibrary(type: "photo")
            } catch {
                NSLog("❌ MediaLibraryPicker: load failed: \(error.localizedDescription)")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(Typography.s36Light)
                .foregroundColor(.white.opacity(0.3))
            Text("No photos in your library yet")
                .font(Typography.s15)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

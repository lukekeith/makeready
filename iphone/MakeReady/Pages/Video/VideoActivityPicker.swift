//
//  VideoActivityPicker.swift
//  MakeReady
//
//  Container view presented as fullScreenCover from EditDay.
//  Two full-screen panels (recorder + library grid) in a vertical stack.
//  Separate drag gestures avoid conflicts with the grid's ScrollView:
//    - Swipe up on recorder panel → reveals grid
//    - Pull down on library header → reveals recorder
//
//  Drag tracking uses @GestureState (bypasses SwiftUI render pipeline → no jitter).
//  On release, the drag value transfers to @State committedDrag for animated settle.
//

import SwiftUI
import Photos

struct VideoActivityPicker: View {
    let onDismiss: () -> Void
    let onVideoSelected: (SelectedVideoResult) -> Void

    @StateObject private var photoLibrary = PhotoLibraryManager.shared

    @State private var showingLibrary = false
    @State private var measuredHeight: CGFloat = 0

    /// @GestureState for jitter-free drag tracking on the recorder panel.
    @GestureState private var recorderDrag: CGFloat = 0

    /// @GestureState for jitter-free drag tracking on the library header.
    @GestureState private var headerDrag: CGFloat = 0

    /// Receives the drag value from @GestureState in .onEnded (before visual reset),
    /// then animates to 0 alongside showingLibrary for a smooth settle.
    @State private var committedDrag: CGFloat = 0

    /// Swipe-to-dismiss offset (downward drag on recorder panel).
    @State private var dismissDrag: CGFloat = 0

    /// Safe area top inset read from UIKit window — reliable inside .ignoresSafeArea().
    private var topSafeArea: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return 59 }
        return window.safeAreaInsets.top
    }

    /// Background opacity fades as the user drags down to dismiss.
    private var backgroundOpacity: Double {
        let screenHeight = Screen.bounds.height
        guard screenHeight > 0 else { return 1 }
        return max(0, 1 - Double(dismissDrag) / Double(screenHeight) * 1.5)
    }

    var body: some View {
        ZStack {
            Color.appBackground.opacity(backgroundOpacity)
                .ignoresSafeArea()

            GeometryReader { geometry in
                // With .ignoresSafeArea(), geometry.size already includes full screen height.
                let screenHeight = geometry.size.height

                VStack(spacing: 0) {
                    // Panel 1: Recorder (full screen)
                    recorderPanel
                        .frame(height: screenHeight)

                    // Panel 2: Library grid (full screen)
                    libraryPanel
                        .frame(height: screenHeight)
                }
                .offset(y: (showingLibrary ? -measuredHeight : 0) + recorderDrag + headerDrag + committedDrag)
                .onAppear {
                    measuredHeight = screenHeight
                }
                .onChange(of: screenHeight) { _, newValue in
                    measuredHeight = newValue
                }
            }
            .offset(y: dismissDrag)
        }
        .ignoresSafeArea()
        .presentationBackground(.clear)
        .task {
            await photoLibrary.ensureAuthorized()
        }
    }

    // MARK: - Recorder Drag Gesture (swipe up → library, swipe down → dismiss)

    /// Bidirectional drag on the recorder panel:
    ///   - Swipe up → reveals library grid (uses @GestureState recorderDrag for jitter-free tracking)
    ///   - Swipe down → dismisses the picker (uses @State dismissDrag for animated settle)
    private var recorderSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .global)
            .updating($recorderDrag) { value, state, transaction in
                transaction.animation = nil
                let drag = value.translation.height
                // Only track upward drags via @GestureState (library reveal)
                if drag < 0 {
                    state = drag
                }
            }
            .onChanged { value in
                let drag = value.translation.height
                // Track downward drags via @State (dismiss) — can't use @GestureState
                // because we need to animate the settle on release
                if drag > 0 {
                    dismissDrag = drag
                }
            }
            .onEnded { value in
                let drag = value.translation.height

                if drag < 0 {
                    // Swipe up → library
                    committedDrag = drag

                    let velocity = value.predictedEndTranslation.height - drag

                    if drag < -100 || velocity < -300 {
                        withAnimation(Motion.modalPresent) {
                            showingLibrary = true
                            committedDrag = 0
                        }
                    } else {
                        withAnimation(Motion.springSnappy) {
                            committedDrag = 0
                        }
                    }
                } else if drag > 0 {
                    // Swipe down → dismiss or snap back
                    let screenHeight = Screen.bounds.height
                    let velocityPts = value.predictedEndTranslation.height - drag
                    let pastThreshold = drag > screenHeight * 0.35
                    let flicked = velocityPts > 500

                    if pastThreshold || flicked {
                        let remaining = screenHeight - dismissDrag
                        let initialVelocity = remaining > 0 ? velocityPts / remaining : 1
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30, initialVelocity: Double(initialVelocity))) {
                            dismissDrag = screenHeight
                        }
                        let settleTime = max(0.2, min(0.4, Double(remaining) / max(Double(velocityPts), 800)))
                        DispatchQueue.main.asyncAfter(deadline: .now() + settleTime) {
                            onDismiss()
                        }
                    } else {
                        let initialVelocity = dismissDrag > 0 ? -velocityPts / dismissDrag : 0
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30, initialVelocity: Double(initialVelocity))) {
                            dismissDrag = 0
                        }
                    }
                }
            }
    }

    // MARK: - Library Header Pull-Down Gesture

    /// Pull down on the library header to return to the recorder.
    /// Gesture is on the header only — doesn't interfere with the grid's ScrollView.
    private var headerPullDownGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .global)
            .updating($headerDrag) { value, state, transaction in
                transaction.animation = nil
                let drag = value.translation.height
                if drag > 0 {
                    state = drag
                }
            }
            .onEnded { value in
                let drag = value.translation.height
                guard drag > 0 else { return }

                committedDrag = drag

                let velocity = value.predictedEndTranslation.height - drag

                if drag > 80 || velocity > 300 {
                    withAnimation(Motion.modalPresent) {
                        showingLibrary = false
                        committedDrag = 0
                    }
                } else {
                    withAnimation(Motion.springSnappy) {
                        committedDrag = 0
                    }
                }
            }
    }

    // MARK: - Recorder Panel

    private var recorderPanel: some View {
        CustomVideoRecorder(
            isPresented: .constant(true),
            onVideoRecorded: { url in
                let result = SelectedVideoResult(asset: nil, recordedURL: url)
                onVideoSelected(result)
            },
            onOpenLibrary: {
                withAnimation(Motion.modalPresent) {
                    showingLibrary = true
                }
            },
            onDismiss: {
                onDismiss()
            },
            topSafeArea: topSafeArea,
            isCameraActive: !showingLibrary,
            transparentBackground: true
        )
        .contentShape(Rectangle())
        .gesture(recorderSwipeGesture)
    }

    // MARK: - Library Panel

    private var libraryPanel: some View {
        VStack(spacing: 0) {
            // Header with album selection menu + pull-down gesture.
            // simultaneousGesture lets the Menu's tap (album dropdown) coexist
            // with the parent drag gesture; using `.gesture` claims the touch
            // first and prevents the Menu from opening, which made it look
            // like the Library button was "hiding" with no dropdown shown.
            libraryHeader
                .contentShape(Rectangle())
                .simultaneousGesture(headerPullDownGesture)

            // Grid — reads from photoLibrary reactively, scrolls independently
            VideoLibraryGrid(
                onVideoSelected: { result in
                    // Animate picker off-screen before triggering parent callback
                    // to avoid the VStack offset snapping back to the recorder panel
                    let screenHeight = Screen.bounds.height
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                        dismissDrag = screenHeight
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onVideoSelected(result)
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    // MARK: - Library Header

    private var libraryHeader: some View {
        HStack {
            // Library source menu
            Menu {
                Button {
                    photoLibrary.selectedAlbum = nil
                } label: {
                    Label("All Videos", systemImage: photoLibrary.selectedAlbum == nil ? "checkmark" : "video")
                }

                if !photoLibrary.albums.isEmpty {
                    Divider()

                    ForEach(photoLibrary.albums) { album in
                        Button {
                            photoLibrary.selectedAlbum = album
                        } label: {
                            Label(
                                "\(album.title) (\(album.count))",
                                systemImage: photoLibrary.selectedAlbum?.id == album.id ? "checkmark" : "folder"
                            )
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(photoLibrary.selectedAlbum?.title ?? "Library")
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)

                    Image(systemName: "chevron.down")
                        .font(Typography.s12Semibold)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .padding(.top, topSafeArea)
        .animation(.none, value: photoLibrary.selectedAlbum?.id)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Text("Library")
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)

                    Image(systemName: "chevron.down")
                        .font(Typography.s12Semibold)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)

            VideoLibraryGrid(
                onVideoSelected: { result in
                    NSLog("Selected: \(result)")
                }
            )
        }
    }
}

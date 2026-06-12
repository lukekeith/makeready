//
//  VideoRecorderPage.swift
//  MakeReady
//
//  Native camera view for recording videos
//

import SwiftUI
import AVFoundation
import UIKit

struct VideoRecorderPage: View {
    @Binding var isPresented: Bool
    var onVideoRecorded: ((URL) -> Void)?

    @State private var showImagePicker = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            CameraViewControllerRepresentable(
                isPresented: $isPresented,
                onVideoRecorded: onVideoRecorded
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Camera View Controller

struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onVideoRecorded: ((URL) -> Void)?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoMaximumDuration = 300 // 5 minutes max
        picker.videoQuality = .typeHigh
        picker.cameraCaptureMode = .video
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraViewControllerRepresentable

        init(_ parent: CameraViewControllerRepresentable) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                // Copy to temp directory to ensure we have access
                let tempDir = FileManager.default.temporaryDirectory
                let filename = UUID().uuidString + ".mov"
                let destURL = tempDir.appendingPathComponent(filename)

                do {
                    try FileManager.default.copyItem(at: videoURL, to: destURL)
                    parent.onVideoRecorded?(destURL)
                } catch {
                    // The user just recorded a video and it was lost — surface it.
                    // No retry: the picker's temp file is gone once the delegate returns.
                    Task { @MainActor in
                        AppState.shared.recordError(
                            error,
                            context: "CameraViewControllerRepresentable.Coordinator.didFinishPickingMedia",
                            surface: true,
                            friendlyMessage: "Couldn't save the recorded video"
                        )
                    }
                }
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Video Recording Button (for custom camera UI)

struct RecordButton: View {
    @Binding var isRecording: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)

                // Inner button (circle when not recording, square when recording)
                if isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 56, height: 56)
                }
            }
        }
    }
}

// MARK: - Video Recording with Upload

struct VideoRecordAndUploadPage: View {
    @Binding var isPresented: Bool
    var onVideoUploaded: ((Video) -> Void)?

    private var state: AppState { AppState.shared }
    @State private var recordedVideoURL: URL?
    @State private var showRecorder = true
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if showRecorder {
                VideoRecorderPage(
                    isPresented: $showRecorder,
                    onVideoRecorded: { url in
                        recordedVideoURL = url
                        showRecorder = false
                        Task {
                            await uploadVideo(url)
                        }
                    }
                )
            } else if state.loadingStates.isLoading("video-upload") {
                uploadProgressView
            }
        }
        .onChange(of: showRecorder) { _, isShowing in
            if !isShowing && recordedVideoURL == nil {
                // User cancelled recording
                isPresented = false
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text(errorMessage)
        }
    }

    private var uploadProgressView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            if let progress = state.uploadProgress {
                VStack(spacing: 8) {
                    ProgressView(value: progress.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                        .frame(width: 200)

                    Text("Uploading... \(progress.percentage)%")
                        .font(Typography.s15)
                        .foregroundColor(.white)
                }
            } else {
                Text("Preparing upload...")
                    .font(Typography.s15)
                    .foregroundColor(.white)
            }

            Button {
                VideoActions().cancelUpload()
                isPresented = false
            } label: {
                Text("Cancel")
                    .font(Typography.s15Medium)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 8)
        }
    }

    private func uploadVideo(_ url: URL) async {
        do {
            let video = try await VideoActions().uploadAndCreateVideo(
                from: url,
                title: nil,
                description: nil
            )

            // Clean up temp file
            try? FileManager.default.removeItem(at: url)

            await MainActor.run {
                onVideoUploaded?(video)
                isPresented = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VideoRecorderPage(isPresented: .constant(true))
}

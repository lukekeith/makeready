//
//  CoverImagePicker.swift
//  MakeReady
//
//  Created by Claude on 2025-11-22.
//

import SwiftUI
import PhotosUI
import QuickLook

enum CoverImagePickerMode {
    case editable  // Entire component is clickable, opens photo picker
    case display   // Edit icon in top-right, tap image opens viewer
}

struct CoverImagePicker: View {
    @Binding var selectedImage: UIImage?
    let programName: String
    let programDescription: String
    var mode: CoverImagePickerMode = .editable
    var existingImageUrl: String? = nil

    @State private var showPhotoPicker = false
    @State private var imagePreviewURL: URL?

    var body: some View {
        Group {
            if mode == .editable {
                editableView
            } else {
                displayView
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PHPickerViewControllerWrapper(selectedImage: $selectedImage)
        }
        .quickLookPreview($imagePreviewURL)
    }

    // MARK: - Editable Mode (Original Behavior)

    private var editableView: some View {
        Button(action: {
            showPhotoPicker = true
        }) {
            coverImageContent
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Display Mode (View/Edit Variant)

    private var displayView: some View {
        ZStack(alignment: .topTrailing) {
            // Image content (no tap gesture - only edit button works)
            coverImageContent

            // Edit icon button in top-right
            Button(action: {
                showPhotoPicker = true
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }
            .padding(16)
        }
    }

    // MARK: - Shared Content

    private var coverImageContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Background or selected image
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: 240)
                } else if let urlString = existingImageUrl, let url = URL(string: urlString) {
                    // Show existing image from URL (for edit mode)
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: 240)
                    } placeholder: {
                        Color.white.opacity(0.1)
                    }
                } else {
                    // Empty state background
                    Color.white.opacity(0.2)
                }

                // Bottom gradient overlay (always present)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#0d101a").opacity(0),
                        Color(hex: "#0d101a")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Dynamic text overlay
                VStack(alignment: .leading, spacing: 4) {
                    // Check if we have any image (selected or existing)
                    let hasImage = selectedImage != nil || existingImageUrl != nil

                    // Check if we have a program name first
                    if !programName.trimmingCharacters(in: .whitespaces).isEmpty {
                        // Show program name (with or without image)
                        Text(programName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if !programDescription.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(programDescription)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(2)
                                .truncationMode(.tail)
                        } else if !hasImage {
                            // Show "Add cover image" as secondary text when no image
                            Text("Add cover image")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    } else if !hasImage {
                        // No name, no image - "Add cover image"
                        Text("Add cover image")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.white.opacity(0.2))
                    } else {
                        // Has image, no name - "Add program name"
                        Text("Add program name")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: geometry.size.width, height: 240)
            .clipped()
        }
        .frame(height: 240)
    }
}

// MARK: - PHPickerViewController Wrapper

struct PHPickerViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerViewControllerWrapper

        init(_ parent: PHPickerViewControllerWrapper) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(hex: "#0d101a")
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 20) {
                Text("Editable Mode")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                // State 1: No image
                CoverImagePicker(
                    selectedImage: .constant(nil),
                    programName: "",
                    programDescription: "",
                    mode: .editable
                )

                // State 2: Image + title + description
                CoverImagePicker(
                    selectedImage: .constant(UIImage(systemName: "photo")),
                    programName: "Romans",
                    programDescription: "A comprehensive study of the whole book",
                    mode: .editable
                )

                Text("Display Mode")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                // State 3: Display mode with image
                CoverImagePicker(
                    selectedImage: .constant(UIImage(systemName: "photo")),
                    programName: "Romans",
                    programDescription: "A comprehensive study of the whole book",
                    mode: .display
                )

                // State 4: Display mode without image
                CoverImagePicker(
                    selectedImage: .constant(nil),
                    programName: "Genesis",
                    programDescription: "In the beginning...",
                    mode: .display
                )

                Spacer()
            }
        }
    }
}

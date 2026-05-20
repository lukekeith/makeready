//
//  CameraCaptureWrapper.swift
//  MakeReady
//
//  UIImagePickerController wrapper restricted to the rear camera, mirroring
//  the PHPickerViewControllerWrapper pattern in CoverImagePicker.swift.
//
//  Used by the read-block background picker (and any other place that needs
//  to capture a still photo with the device camera). Requires
//  NSCameraUsageDescription in Info.plist (already present).
//

import SwiftUI
import UIKit

struct CameraCaptureWrapper: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureWrapper

        init(_ parent: CameraCaptureWrapper) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            parent.capturedImage = image
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

//
//  ModalAnimations.swift
//  MakeReady
//
//  Unified modal animation helpers to prevent curve conflicts.
//  Using separate animation blocks for offset vs opacity creates jitter
//  because SwiftUI runs competing animations with different curves.
//
//  Usage:
//  ```swift
//  // In onAppear:
//  ModalAnimations.animateAppear(offset: $offset, overlayOpacity: $overlayOpacity)
//
//  // In dismiss:
//  ModalAnimations.animateDismiss(
//      offset: $offset,
//      overlayOpacity: $overlayOpacity,
//      screenHeight: UIScreen.main.bounds.height
//  ) {
//      overlayManager.dismiss(id: id)
//  }
//  ```
//

import SwiftUI

enum ModalAnimations {
    /// Standard modal appear animation (spring)
    static let appear = Animation.spring(response: 0.4, dampingFraction: 0.85)

    /// Standard modal dismiss animation (faster spring)
    static let dismiss = Animation.spring(response: 0.3, dampingFraction: 0.85)

    /// Default animation duration for timing completion callbacks
    static let dismissDuration: Double = 0.3

    /// Perform modal appear with single animation block
    /// This prevents jitter caused by competing animation curves
    static func animateAppear(
        offset: Binding<CGFloat>,
        overlayOpacity: Binding<Double>,
        targetOpacity: Double = 0.5
    ) {
        withAnimation(appear) {
            offset.wrappedValue = 0
            overlayOpacity.wrappedValue = targetOpacity
        }
    }

    /// Perform modal dismiss with single animation block
    /// This prevents jitter caused by competing animation curves
    static func animateDismiss(
        offset: Binding<CGFloat>,
        overlayOpacity: Binding<Double>,
        screenHeight: CGFloat,
        completion: @escaping () -> Void
    ) {
        withAnimation(dismiss) {
            offset.wrappedValue = screenHeight
            overlayOpacity.wrappedValue = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration) {
            completion()
        }
    }

    /// Perform content appear animation (scale + opacity)
    /// Used for overlays with scale effect like ConfirmationOverlay
    static func animateContentAppear(
        scale: Binding<CGFloat>,
        opacity: Binding<Double>,
        blurOpacity: Binding<Double>? = nil
    ) {
        withAnimation(appear) {
            scale.wrappedValue = 1
            opacity.wrappedValue = 1
            blurOpacity?.wrappedValue = 1
        }
    }

    /// Perform content dismiss animation (scale + opacity)
    static func animateContentDismiss(
        scale: Binding<CGFloat>,
        opacity: Binding<Double>,
        blurOpacity: Binding<Double>? = nil,
        targetScale: CGFloat = 0.9,
        completion: @escaping () -> Void
    ) {
        withAnimation(dismiss) {
            scale.wrappedValue = targetScale
            opacity.wrappedValue = 0
            blurOpacity?.wrappedValue = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration) {
            completion()
        }
    }
}

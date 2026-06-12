//
//  ErrorBanner.swift
//  MakeReady
//
//  Top error banner (Decision Point A). Surfaces failures of actions the
//  user just took — background refresh failures never show here (they stay
//  console-only; see AppState.recordError).
//
//  Behavior: slides down from the top, auto-dismisses after 4 seconds,
//  swipe-up or tap dismisses early, a new surfaced error replaces the
//  current one. When the error carries a retry closure, a retry button
//  re-runs the failed operation.
//
//  Host: ErrorBannerHost is mounted ONCE, at the very top of MainView's
//  layer stack (above all overlays — errors can originate from modal
//  flows). Don't mount additional hosts.
//

import SwiftUI

/// Observes `AppState.activeSurfacedError` and presents/dismisses the
/// banner. Animation follows the codebase toast pattern: content under an
/// `if let`, container-level `.animation(value:)` keyed to the error id.
struct ErrorBannerHost: View {
    private var state: AppState { AppState.shared }

    /// Auto-dismiss timer — replaced when a new error arrives, cancelled on
    /// manual dismissal. Task.sleep (not asyncAfter) so cancellation works.
    @State private var dismissTask: Task<Void, Never>? = nil

    var body: some View {
        VStack {
            if let error = state.activeSurfacedError {
                ErrorBanner(
                    message: error.message,
                    onRetry: error.retry.map { retry in
                        {
                            dismiss()
                            retry()
                        }
                    },
                    onDismiss: { dismiss() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(error.id)
            }

            Spacer()
        }
        .animation(Motion.standard, value: state.activeSurfacedError?.id)
        .onChange(of: state.activeSurfacedError?.id) { _, newId in
            dismissTask?.cancel()
            guard newId != nil else { return }
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        state.activeSurfacedError = nil
    }
}

/// The banner itself — pure presentation.
struct ErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)? = nil
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Typography.s14)
                .foregroundColor(.white)

            Text(message)
                .font(Typography.s14Semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)

            if let onRetry {
                Button(action: onRetry) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(Typography.s12Semibold)
                        Text("Retry")
                            .font(Typography.s13Semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.error)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .gesture(
            DragGesture(minimumDistance: 15)
                .onEnded { value in
                    if value.translation.height < -20 {
                        onDismiss()
                    }
                }
        )
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 16) {
            ErrorBanner(
                message: "Couldn't save changes",
                onRetry: { },
                onDismiss: { }
            )

            ErrorBanner(
                message: "Upload failed — the file may be too large to process",
                onDismiss: { }
            )

            Spacer()
        }
    }
}

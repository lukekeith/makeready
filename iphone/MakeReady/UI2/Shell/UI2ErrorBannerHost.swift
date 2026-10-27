import SwiftUI

/// invite-member Fixes (agent walk round 1, E6): the 2.0 shell's host for `recordError(surface: true)`.
/// ui2-shell D28 left the legacy `ErrorBannerHost` behind with `Components/` and named "a 2.0 error host"
/// a later feature's; invite-member is the first 2.0 mutation that surfaces one (D10, D12, D13).
/// Stopgap until a designed 2.0 banner is specced: the legacy behaviour (slides down from the top,
/// auto-dismisses after 4 s, tap or swipe up dismisses, a new error replaces the current one) drawn
/// with 2.0 tokens. Mounted ONCE, in `UI2Shell`, above every piece of chrome.
struct UI2ErrorBannerHost: View {
    static let autoDismiss: Duration = .seconds(4)

    /// What the banner says for the error on screen — nil hides it.
    static func message(for error: AppError?) -> String? {
        guard let error, error.surface else { return nil }
        return error.message
    }

    private var state: AppState { AppState.shared }
    @State private var dismissTask: Task<Void, Never>? = nil

    var body: some View {
        VStack {
            if let error = state.activeSurfacedError, let message = Self.message(for: error) {
                banner(message, kind: error.kind)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(error.id)
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: state.activeSurfacedError?.id)
        .onChange(of: state.activeSurfacedError?.id) { _, newId in
            dismissTask?.cancel()
            guard newId != nil else { return }
            dismissTask = Task {
                try? await Task.sleep(for: Self.autoDismiss)
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
    }

    private func banner(_ message: String, kind: AppMessageKind) -> some View {
        HStack(spacing: 12) {
            Image(systemName: kind == .notice ? "info.circle.fill" : "exclamationmark.triangle.fill")
            Text(message)
                .designTextStyle(Token.TypeStyle.labelEmphasis)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
        .foregroundStyle(Token.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(kind == .notice ? Token.cardBackground : Token.error)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ui2-error-banner")
        .onTapGesture { dismiss() }
        .gesture(DragGesture(minimumDistance: 15).onEnded { if $0.translation.height < -20 { dismiss() } })
    }

    private func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        state.activeSurfacedError = nil
    }
}

//
//  ReadActivityPreviewModal.swift
//  MakeReady
//
//  Full-screen preview modal for READ activities.
//
//  Loads the canonical web preview (app.makeready.org/preview/activity/{id})
//  in a WKWebView. All rendering, playback, scrubbing, and tap-to-pause are
//  handled by the web client's `ActivityPreviewPlayer.vue` — a single source
//  of truth shared between the iPhone WebView and desktop browsers.
//
//  Auth: the iPhone's OAuth session cookie (`connect.sid` in UserDefaults)
//  is planted into the WebView's private cookie store scoped to `.makeready.org`
//  before navigation, so the server-side `/api/activities/:id/preview-data`
//  fetch authenticates automatically. The cookie lives only in this WebView's
//  WKWebsiteDataStore — it does not leak to Safari or other apps.
//

import SwiftUI
import WebKit

// MARK: - Modal

struct ReadActivityPreviewModal: View {
    let activityId: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header bar with close button
            HStack {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(Typography.s13Semibold)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Preview")
                    .font(Typography.s15Semibold)
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                // Invisible balance for centering
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.backgroundDark)

            // Preview content
            PreviewWebView(activityId: activityId)
        }
        .background(Color.backgroundDark)
    }
}

// MARK: - WKWebView wrapper

struct PreviewWebView: UIViewRepresentable {
    let activityId: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Color.backgroundDark)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator

        loadPreview(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    /// Request a short-lived preview token from the API, build the preview
    /// URL with the token as a query param, then load. No cookie planting needed.
    private func loadPreview(into webView: WKWebView) {
        guard let baseURL = Self.buildPreviewURL(activityId: activityId) else {
            NSLog("❌ ActivityPreview: could not build URL (activityId=\(activityId))")
            return
        }

        _ = Task {
            do {
                let token = try await Self.fetchPreviewToken()
                let url = URL(string: "\(baseURL.absoluteString)?preview_token=\(token)")!
                NSLog("👁️ ActivityPreview: loading \(url.absoluteString)")
                _ = await MainActor.run {
                    webView.load(URLRequest(url: url))
                }
            } catch {
                NSLog("❌ ActivityPreview: failed to get preview token — \(error.localizedDescription)")
                // Fall back to loading without token (will likely 404)
                _ = await MainActor.run {
                    webView.load(URLRequest(url: baseURL))
                }
            }
        }
    }

    /// Request a short-lived preview token (see ThemeActions.fetchPreviewToken)
    static func fetchPreviewToken() async throws -> String {
        try await ThemeActions().fetchPreviewToken()
    }

    static func buildPreviewURL(activityId: String) -> URL? {
        let template = "\(Configuration.clientBaseURL)/preview/activity/{activityId}"
        let encoded = activityId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? activityId
        let raw = template.replacingOccurrences(of: "{activityId}", with: encoded)
        return URL(string: raw)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            NSLog("❌ ActivityPreview: navigation failed — %@", error.localizedDescription)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            NSLog("❌ ActivityPreview: provisional navigation failed — %@", error.localizedDescription)
        }
    }
}

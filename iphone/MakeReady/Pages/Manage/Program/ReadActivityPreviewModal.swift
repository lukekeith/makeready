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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Preview")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                // Invisible balance for centering
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#0a0a0f"))

            // Preview content
            PreviewWebView(activityId: activityId)
        }
        .background(Color(hex: "#0a0a0f"))
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
        webView.backgroundColor = UIColor(Color(hex: "#0a0a0f"))
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator

        loadPreview(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    /// Build the preview URL from the template served by /api/themes, plant
    /// the session cookie into the WebView's private cookie store, then load.
    private func loadPreview(into webView: WKWebView) {
        guard let url = Self.buildPreviewURL(activityId: activityId) else {
            NSLog("❌ ActivityPreview: could not build URL (activityId=\(activityId))")
            return
        }

        let sessionValue = APIClient.shared.sessionCookieValue ?? ""
        if sessionValue.isEmpty {
            NSLog("⚠️ ActivityPreview: no session cookie available — preview may redirect to login")
        }

        // Percent-encode before planting so `=`, `+`, `/` etc. in signed-cookie
        // HMAC values survive the HTTPCookie → Cookie header → Laravel proxy
        // chain without parser ambiguity. ApiService::extractApiCookies calls
        // urldecode() before forwarding to the API, restoring the raw value.
        let encodedValue = sessionValue.addingPercentEncoding(
            withAllowedCharacters: Self.cookieValueAllowed
        ) ?? sessionValue

        let cookieProps = Self.cookieProperties(for: url, sessionValue: encodedValue)
        guard let cookie = HTTPCookie(properties: cookieProps) else {
            NSLog("❌ ActivityPreview: failed to construct HTTPCookie")
            webView.load(URLRequest(url: url))
            return
        }

        NSLog("👁️ ActivityPreview: loading \(url.absoluteString)")
        webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
            webView.load(URLRequest(url: url))
        }
    }

    /// Substitute `{activityId}` into the template from AppState, falling back
    /// to `Configuration.clientBaseURL + /preview/activity/{id}` so previews
    /// still work even if /api/themes hasn't returned yet (offline/first launch).
    static func buildPreviewURL(activityId: String) -> URL? {
        let template = AppState.shared.previewUrlTemplate
            ?? "\(Configuration.clientBaseURL)/preview/activity/{activityId}"
        let encoded = activityId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? activityId
        let raw = template.replacingOccurrences(of: "{activityId}", with: encoded)
        return URL(string: raw)
    }

    /// Alphanumerics plus `.-_~:` only. `=`, `+`, `/` and other base64-padding
    /// characters that appear in signed-cookie HMACs are percent-encoded so
    /// the value survives HTTPCookie → Cookie header → Laravel `$request->header('Cookie')`
    /// → `explode(';')` / `strpos('=')` parsing. ApiService::extractApiCookies
    /// urldecodes on the far side before forwarding to the API.
    static let cookieValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: ".-_~:")
        return set
    }()

    /// Build cookie properties appropriate for the target URL's host + scheme.
    /// Prod uses `.makeready.org` so both `app.` and `api.` subdomains see it
    /// inside the WebView's private cookie jar. Local dev (localhost) omits
    /// the leading dot and drops the Secure flag.
    static func cookieProperties(for url: URL, sessionValue: String) -> [HTTPCookiePropertyKey: Any] {
        let host = url.host ?? "localhost"
        let isSecure = url.scheme == "https"
        let domain: String
        if host == "localhost" || host.hasPrefix("127.") {
            domain = host
        } else if host.hasSuffix("makeready.org") {
            domain = ".makeready.org"
        } else {
            domain = host
        }
        return [
            .domain: domain,
            .path:   "/",
            .name:   "connect.sid",
            .value:  sessionValue,
            .secure: isSecure,
        ]
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

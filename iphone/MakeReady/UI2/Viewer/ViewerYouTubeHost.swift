import SwiftUI
import WebKit

/// text-activity D24: a `youtube` page's player, in the screen's `youtubeSlot`. YouTube's terms
/// require its own player, so this is a `WKWebView` holding one IFrame-API embed and nothing else:
/// the page is a fixed wrapper this host writes, its one frame may only load
/// `https://www.youtube.com/embed/…` or `https://www.youtube-nocookie.com/embed/…`, and every other
/// navigation (YouTube's logo, "Watch on YouTube", a new window) is cancelled. Controls and captions
/// are YouTube's (02 §8). When the page stops being active the player is paused through the IFrame
/// API's `pauseVideo` command; it never starts on its own.
struct ViewerYouTubeHost: UIViewRepresentable {
    let videoId: String
    let startSeconds: Double?
    let endSeconds: Double?
    /// Whether this page covers the viewport's midline (01 §7).
    let active: Bool

    /// The only hosts and path the player may navigate to.
    static let embedHosts: Set<String> = ["www.youtube.com", "www.youtube-nocookie.com"]
    static let embedPath = "/embed/"
    /// The wrapper's origin, so YouTube sees an embedding site (it refuses an embed with none).
    static let wrapperBaseURL = URL(string: "https://app.makeready.org/")

    /// D24: an https URL on YouTube's embed player, and nothing else.
    static func allows(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host, embedHosts.contains(host) else { return false }
        return url.path.hasPrefix(embedPath) && url.path.count > embedPath.count
    }

    /// The embed player for one video, with the IFrame API on and inline playback.
    static func embedURL(videoId: String, startSeconds: Double?, endSeconds: Double? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube-nocookie.com"
        components.path = embedPath + videoId
        var query = [URLQueryItem(name: "enablejsapi", value: "1"), URLQueryItem(name: "playsinline", value: "1")]
        if let startSeconds, startSeconds > 0 { query.append(URLQueryItem(name: "start", value: String(Int(startSeconds)))) }
        if let endSeconds, endSeconds > 0 { query.append(URLQueryItem(name: "end", value: String(Int(endSeconds)))) }
        components.queryItems = query
        return components.url
    }

    /// The wrapper page: one full-bleed iframe, and the IFrame API's command channel to it.
    static func wrapperHTML(embed: URL) -> String {
        """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">\
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}\
        iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0}</style></head><body>\
        <iframe id="player" src="\(embed.absoluteString)" allow="autoplay; encrypted-media; picture-in-picture" \
        allowfullscreen></iframe><script>function playerCommand(name){var f=document.getElementById('player');\
        if(f&&f.contentWindow){f.contentWindow.postMessage(JSON.stringify({event:'command',func:name,args:[]}),'*');}}\
        </script></body></html>
        """
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        // The pager owns vertical movement (01 §5); the page itself never scrolls.
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        if let embed = Self.embedURL(videoId: videoId, startSeconds: startSeconds, endSeconds: endSeconds) {
            context.coordinator.loadingWrapper = true
            webView.loadHTMLString(Self.wrapperHTML(embed: embed), baseURL: Self.wrapperBaseURL)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // D24: paused at the midline on the way out.
        if context.coordinator.wasActive, !active {
            webView.evaluateJavaScript("playerCommand('pauseVideo')") { _, error in
                // Silent: a player that hasn't loaded yet has nothing playing to pause.
                if let error { Log.ui.debug("youtube pause skipped: \(error.localizedDescription, privacy: .public)") }
            }
        }
        context.coordinator.wasActive = active
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        /// True until the wrapper's own load is decided; it's the one main-frame load allowed.
        var loadingWrapper = false
        var wasActive = false

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .cancel }
            if navigationAction.targetFrame?.isMainFrame ?? true {
                let allowed = loadingWrapper
                loadingWrapper = false
                return allowed ? .allow : .cancel
            }
            // The embed's own frame: the player, or a blank frame it opens for itself.
            return ViewerYouTubeHost.allows(url) || url.scheme == "about" ? .allow : .cancel
        }

        /// Once the wrapper has committed, no other main-frame load is allowed.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            loadingWrapper = false
        }

        /// A link asking for a new window opens nothing.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            nil
        }
    }
}

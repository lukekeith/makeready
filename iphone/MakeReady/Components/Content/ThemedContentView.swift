//
//  ThemedContentView.swift
//  MakeReady
//
//  WKWebView wrapper that renders themed text content using the Vue theme renderer.
//  Loads a bundled HTML file and injects content + theme definition via JavaScript bridge.
//

import SwiftUI
import WebKit

struct ThemedContentView: UIViewRepresentable {
    let content: String
    let themeDefinition: String?  // JSON string of the theme definition
    var contentFormat: String = "markdown"
    var sourceReference: [String: Any]? = nil
    var verses: [[String: Any]]? = nil
    var isLocked: Bool = false
    var onSequenceComplete: (() -> Void)? = nil
    var onPhaseChange: ((Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        // Set up message handler for JS → Swift communication
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "themeEvent")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        // Load the bundled HTML
        if let htmlPath = Bundle.main.path(forResource: "themed-content", ofType: "html") {
            let htmlURL = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            NSLog("⚠️ ThemedContentView: themed-content.html not found in bundle")
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        // Inject content after page loads (handled by navigationDelegate)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: ThemedContentView

        init(_ parent: ThemedContentView) {
            self.parent = parent
        }

        // Called when the HTML page finishes loading
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectContent(into: webView)
        }

        private func injectContent(into webView: WKWebView) {
            // Build the renderTheme() call
            var data: [String: Any] = [
                "content": parent.content,
                "contentFormat": parent.contentFormat,
                "isLocked": parent.isLocked,
            ]

            if parent.themeDefinition != nil {
                data["theme"] = "__THEME_PLACEHOLDER__"
            }

            if let sourceRef = parent.sourceReference {
                data["sourceReference"] = sourceRef
            }

            if let verses = parent.verses {
                data["verses"] = verses
            }

            // Serialize to JSON
            guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
                  var jsonString = String(data: jsonData, encoding: .utf8) else {
                NSLog("⚠️ ThemedContentView: Failed to serialize data")
                return
            }

            // Replace theme placeholder with raw JSON (not double-encoded)
            if let themeDef = parent.themeDefinition {
                jsonString = jsonString.replacingOccurrences(
                    of: "\"__THEME_PLACEHOLDER__\"",
                    with: themeDef
                )
            }

            let js = "window.renderTheme(\(jsonString))"
            webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    NSLog("⚠️ ThemedContentView: JS error: \(error)")
                }
            }
        }

        // Handle messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "themeEvent",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            DispatchQueue.main.async { [weak self] in
                switch type {
                case "phase-change":
                    if let index = body["index"] as? Int {
                        self?.parent.onPhaseChange?(index)
                    }
                case "sequence-complete":
                    self?.parent.onSequenceComplete?()
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        ThemedContentView(
            content: "# Hello World\n\nThis is a test of themed content rendering.",
            themeDefinition: nil,
            contentFormat: "markdown"
        )
        .frame(height: 400)
        .padding()
    }
}

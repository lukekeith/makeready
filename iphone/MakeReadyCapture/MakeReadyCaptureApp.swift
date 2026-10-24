//
//  MakeReadyCaptureApp.swift
//  MakeReadyCapture (d2m video-captures D23)
//
//  The capture app: MakeReady's sources plus the seeded-capture sources, launched by the
//  MakeReadyCaptureUITests runner with
//      -captureView <viewKey> -captureDevice <key> -captureJob <path>
//  (UserDefaults reads `-key value` launch arguments). It builds the job's view at its seeded state
//  through the same `buildCaptureCase(for:)` the still CaptureRunner uses, and shows it full screen.
//  Never archived; MakeReady.app compiles none of this.
//

import SwiftUI
@testable import UI2Preview

@main
struct MakeReadyCaptureApp: App {
    @StateObject private var host = CaptureHost()

    var body: some Scene {
        WindowGroup {
            CaptureRootView(host: host)
        }
    }
}

@MainActor
final class CaptureHost: ObservableObject {
    let job: RecordingJob?
    let jobPath: String?
    /// The job file as raw JSON — `state` / `leadsTo[].state` go to the fixture decoder untouched.
    let raw: [String: Any]
    @Published private(set) var root: AnyView?
    @Published private(set) var failure: String?

    init() {
        let defaults = UserDefaults.standard
        jobPath = defaults.string(forKey: "captureJob")
        var job: RecordingJob?
        var raw: [String: Any] = [:]
        do {
            guard let jobPath else { throw CaptureAppError("no -captureJob launch argument") }
            let data = try Data(contentsOf: URL(fileURLWithPath: jobPath))
            job = try JSONDecoder().decode(RecordingJob.self, from: data)
            raw = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            if let view = defaults.string(forKey: "captureView"), view != job?.view {
                throw CaptureAppError("-captureView \(view) does not match the job's view \(job?.view ?? "?")")
            }
        } catch {
            failure = "\(error)"
        }
        self.job = job
        self.raw = raw
        guard let job, failure == nil else { return }
        // Test-only network stubs, exactly as CaptureRunner.setUp registers them.
        URLProtocol.registerClass(MockURLProtocol.self)
        do {
            root = try buildCaptureRoot(view: job.view, device: job.device, title: job.title, state: raw["state"] ?? [:])
        } catch {
            failure = "\(error)"
        }
    }
}

struct CaptureAppError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// A CaptureFixture for one view at one seeded state — the still runner's fixture shape.
func captureFixture(view: String, device: String, title: String, state: Any) throws -> CaptureFixture {
    let body: [String: Any] = ["view": view, "output": "recording.png", "devices": [device], "title": title, "state": state]
    return try JSONDecoder().decode(CaptureFixture.self, from: JSONSerialization.data(withJSONObject: body))
}

/// The view a recording shows: a screen at the device viewport (D6); a component BARE, at the
/// device width, its bounds named `__root` so the worker can crop the video to it (D6, D24).
@MainActor
func buildCaptureRoot(view: String, device: String, title: String, state: Any) throws -> AnyView {
    let fixture = try captureFixture(view: view, device: device, title: title, state: state)
    setupCaptureState(from: fixture)
    let built = try buildCaptureView(for: fixture)
    // This checkout has no PreviewFrame yet (buildCaptureCase/previewView are not in the registry),
    // so a component is always shown bare at the simulator's width — the app runs on the device the
    // job names (D26) — and always named `__root`; the still runner sizes components the same way.
    let content: AnyView
    if view.hasPrefix("component.") {
        content = AnyView(built.frame(maxWidth: .infinity, alignment: .leading).ui2Element("__root"))
    } else {
        // A screen scrolls, top first, as the real app's shell shows it (d2m 2026-10-14): hosted at
        // its full height it was centred in the window, its top cut off and unreachable — a card
        // on the header or a rail above the fold could never be found. Short screens still fill
        // the window (minHeight), so their spacers lay out as on the device.
        content = AnyView(GeometryReader { proxy in
            ScrollView(.vertical) {
                built.frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        })
    }
    return AnyView(
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(UI2Preview.Token.layoutBackground.ignoresSafeArea())
    )
}

struct CaptureRootView: View {
    @ObservedObject var host: CaptureHost
    @StateObject private var session: CaptureSession
    @Environment(\.displayScale) private var displayScale

    init(host: CaptureHost) {
        self.host = host
        _session = StateObject(wrappedValue: CaptureSession(host: host))
    }

    var body: some View {
        ZStack {
            if host.root != nil {
                CaptureLevelView(session: session, depth: 0)
            } else {
                Text(host.failure ?? "loading…")
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if session.markerVisible {
                captureSyncMarkerColor.ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .task { await session.run(scale: displayScale) }
    }
}

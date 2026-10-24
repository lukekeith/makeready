//
//  RecordingJob.swift
//  MakeReadyCapture (d2m video-captures)
//
//  The recording job file d2m's ios-sim adapter writes at <renderJobDir>/recordings/<takeId>.json
//  (SPEC §Contract "Recording job file"), and the report the capture app writes back beside the
//  take's output. Foundation only: compiled into BOTH MakeReadyCapture and MakeReadyCaptureUITests.
//  `state` / `sharedData` are not decoded here — the app reads them raw and hands them to the
//  fixture decoder (CaptureFixture) untouched.
//

import Foundation

struct RecordingJob: Decodable {
    struct Action: Decodable {
        let type: String          // tap | long_press | type_text | swipe | scroll_to | wait (D8)
        let element: String?
        let text: String?
        let direction: String?    // up | down | left | right
        let holdMs: Double?
        let durationMs: Double?
        /// d2m: enclosing elements centred on this one, innermost first — tried when `element` is
        /// not an exposed identifier (an outer `.ui2Element` on the same view replaces it).
        let fallbacks: [String]?
    }

    struct LeadsTo: Decodable {
        let index: Int            // the action after which the target is presented (D10)
        let view: String
        let transition: String    // push | sheet | cover
    }

    let view: String
    let device: String
    let title: String
    let actions: [Action]
    let leadsTo: [LeadsTo]
    /// Absolute base path: `<output>.mov` (record.sh), `<output>.timeline.json` (the UI test),
    /// `<output>.app.json` (this app), `<output>.go-<index>` (the UI test's leadsTo signals).
    let output: String
    /// How long the UI test keeps the app on screen after the last action (the settle cap + margin).
    let tailMs: Double

    static func load(_ path: String) throws -> RecordingJob {
        try JSONDecoder().decode(RecordingJob.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }

    var appReportPath: String { output + ".app.json" }
    var timelinePath: String { output + ".timeline.json" }
    func signalPath(_ index: Int) -> String { output + ".go-\(index)" }
}

/// What the capture app tells the UI test, through `<output>.app.json`.
struct AppReport: Codable {
    /// Epoch ms at which the sync marker went up (F3) — the timeline's `loadedAt`.
    var loadedAt: Double?
    /// Points → pixels for the timeline's element rects (D6).
    var scale: Double?
    /// leadsTo presentations performed: "<action index>" → epoch ms.
    var presented: [String: Double] = [:]
    /// Why the app could not build the job's view; nil when it did.
    var error: String?

    func write(to path: String) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

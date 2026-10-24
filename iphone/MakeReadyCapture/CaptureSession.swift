//
//  CaptureSession.swift
//  MakeReadyCapture (d2m video-captures F3, D10)
//
//  What the capture app does once its view is up, in step with the UI-test runner:
//   1. waits 1 s for the view to settle (images, first layout), then shows a full-screen magenta
//      sync marker for 100 ms and records `loadedAt` (epoch ms, the host clock the simulator
//      shares) — the worker finds the marker's first frame in the video and anchors the timeline
//      to it (F3);
//   2. writes `<output>.app.json` {loadedAt, scale} — the runner's go-ahead;
//   3. polls for `<output>.go-<index>` (written by the runner after action <index>) and presents
//      that leadsTo target — push, sheet or cover — at its seeded state (D10), recording the time.
//  The wiring exists only here: built screens stay unwired.
//

import SwiftUI

/// The sync marker's colour — the worker's detector looks for exactly this (r > 200, g < 60, b > 200).
let captureSyncMarkerColor = Color(red: 1, green: 0, blue: 1)
let captureSyncMarkerMs: UInt64 = 100

@MainActor
final class CaptureSession: ObservableObject {
    struct Level {
        let id: Int               // the leadsTo action index that opened it; -1 for the start view
        let content: AnyView
        let transition: String    // "root" | "sheet" | "cover"
        var path: [Int] = []      // pushes onto this level, by action index
    }

    @Published var levels: [Level] = []
    @Published var markerVisible = false
    private(set) var pushed: [Int: AnyView] = [:]
    private var report = AppReport()
    private let host: CaptureHost

    init(host: CaptureHost) {
        self.host = host
        if let root = host.root { levels = [Level(id: -1, content: root, transition: "root")] }
    }

    func run(scale: CGFloat) async {
        guard let job = host.job else {
            report.error = host.failure ?? "no job"
            if let path = host.jobPath, let output = outputBase(jobPath: path) { report.write(to: output + ".app.json") }
            return
        }
        if let failure = host.failure {
            report.error = failure
            report.write(to: job.appReportPath)
            return
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        markerVisible = true
        report.loadedAt = Date().timeIntervalSince1970 * 1000
        try? await Task.sleep(nanoseconds: captureSyncMarkerMs * 1_000_000)
        markerVisible = false
        report.scale = Double(scale)
        report.write(to: job.appReportPath)

        var pending = job.leadsTo.sorted { $0.index < $1.index }
        let rawLeads = (host.raw["leadsTo"] as? [[String: Any]]) ?? []
        while !pending.isEmpty, !Task.isCancelled {
            let next = pending[0]
            if FileManager.default.fileExists(atPath: job.signalPath(next.index)) {
                try? FileManager.default.removeItem(atPath: job.signalPath(next.index))
                pending.removeFirst()
                let state = rawLeads.first { ($0["index"] as? Int) == next.index }?["state"] ?? [:]
                do {
                    let view = try buildCaptureRoot(view: next.view, device: job.device, title: job.title, state: state)
                    present(view, index: next.index, transition: next.transition)
                    report.presented[String(next.index)] = Date().timeIntervalSince1970 * 1000
                } catch {
                    report.error = "leadsTo \(next.view): \(error)"
                }
                report.write(to: job.appReportPath)
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// push → onto the top level's NavigationStack; sheet / cover → a new level above it.
    private func present(_ view: AnyView, index: Int, transition: String) {
        if transition == "push", !levels.isEmpty {
            pushed[index] = view
            levels[levels.count - 1].path.append(index)
        } else {
            levels.append(Level(id: index, content: view, transition: transition == "cover" ? "cover" : "sheet"))
        }
    }

    private func outputBase(jobPath: String) -> String? {
        guard let data = FileManager.default.contents(atPath: jobPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["output"] as? String
    }
}

/// One presentation level: its own NavigationStack (for pushes) and the sheet / cover above it.
struct CaptureLevelView: View {
    @ObservedObject var session: CaptureSession
    let depth: Int

    var body: some View {
        if depth < session.levels.count {
            NavigationStack(path: pathBinding) {
                session.levels[depth].content
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: Int.self) { index in
                        (session.pushed[index] ?? AnyView(EmptyView()))
                            .toolbar(.hidden, for: .navigationBar)
                    }
            }
            .sheet(isPresented: presented("sheet")) { CaptureLevelView(session: session, depth: depth + 1) }
            .fullScreenCover(isPresented: presented("cover")) { CaptureLevelView(session: session, depth: depth + 1) }
        }
    }

    private var pathBinding: Binding<[Int]> {
        Binding(
            get: { depth < session.levels.count ? session.levels[depth].path : [] },
            set: { if depth < session.levels.count { session.levels[depth].path = $0 } }
        )
    }

    private func presented(_ transition: String) -> Binding<Bool> {
        Binding(
            get: { session.levels.count > depth + 1 && session.levels[depth + 1].transition == transition },
            set: { if !$0, session.levels.count > depth + 1 { session.levels.removeSubrange((depth + 1)...) } }
        )
    }
}

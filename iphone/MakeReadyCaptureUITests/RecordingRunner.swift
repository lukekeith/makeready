//
//  RecordingRunner.swift
//  MakeReadyCaptureUITests (d2m video-captures D7, D8, D25, F2, F3)
//
//  Runs one recording job: launches MakeReadyCapture at the job's view and seeded state, waits for
//  its sync marker, performs the job's actions on real elements by accessibility identifier, and
//  writes `<output>.timeline.json` — epoch-ms times on the host clock the simulator shares, the
//  LIVE XCUIElement frames (points) of every element it touched plus `__root`, and the screen scale.
//  record.sh records the simulator around this test (a UI test cannot exec simctl).
//
//  Env (xcodebuild forwards TEST_RUNNER_<NAME> as <NAME>): CAPTURE_RECORDING=1, CAPTURE_JOB,
//  CAPTURE_RECORD_STARTED_AT and CAPTURE_DEVICE_NAME (both from record.sh). Without
//  CAPTURE_RECORDING the test skips — a plain `xcodebuild test` never records anything.
//

import XCTest

private struct RecordingFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

private struct Timeline: Encodable {
    struct Act: Encodable { let index: Int; let startAt: Double; let endAt: Double; let ok: Bool; let error: String? }
    struct Rect: Encodable { let x: Double; let y: Double; let w: Double; let h: Double }
    let recordStartedAt: Double
    let loadedAt: Double
    var actions: [Act] = []
    var elements: [String: Rect] = [:]
    let scale: Double
    let device: String
}

final class RecordingRunner: XCTestCase {
    private static func now() -> Double { Date().timeIntervalSince1970 * 1000 }

    @MainActor
    func testRecord() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["CAPTURE_RECORDING"] == "1", let jobPath = env["CAPTURE_JOB"] else {
            throw XCTSkip("not a recording run — d2m sets TEST_RUNNER_CAPTURE_RECORDING and TEST_RUNNER_CAPTURE_JOB")
        }
        continueAfterFailure = false
        let job = try RecordingJob.load(jobPath)
        try? FileManager.default.removeItem(atPath: job.appReportPath)
        try? FileManager.default.removeItem(atPath: job.timelinePath)

        let app = XCUIApplication()
        app.launchArguments = ["-captureView", job.view, "-captureDevice", job.device, "-captureJob", jobPath]
        app.launch()

        let report = try waitForReport(job, seconds: 60) { $0.loadedAt != nil || $0.error != nil }
        if let error = report.error {
            XCTFail("CAPTURE: ✗ the capture app could not build \(job.view): \(error)")
            return
        }
        var timeline = Timeline(
            recordStartedAt: Double(env["CAPTURE_RECORD_STARTED_AT"] ?? "") ?? 0,
            loadedAt: report.loadedAt ?? Self.now(),
            scale: report.scale ?? 3,
            device: env["CAPTURE_DEVICE_NAME"] ?? job.device
        )
        let root = element(app, "__root")
        if root.exists || root.waitForExistence(timeout: 1) { timeline.elements["__root"] = rect(root.frame) }
        // F3: the marker is down; one more second keeps it out of any buffer before the first action.
        Thread.sleep(forTimeInterval: 1.0)

        for (index, action) in job.actions.enumerated() {
            // d2m shows this live over the player ("Recording — step 3 of 12"); record.sh relays it as it prints.
            print("CAPTURE: step \(index + 1)/\(job.actions.count)")
            let startAt = Self.now()
            do {
                try perform(action, in: app, timeline: &timeline)
                if job.leadsTo.contains(where: { $0.index == index }) {
                    FileManager.default.createFile(atPath: job.signalPath(index), contents: Data())
                    let answer = try waitForReport(job, seconds: 5) { $0.presented[String(index)] != nil || $0.error != nil }
                    if let error = answer.error { throw RecordingFailure(error) }
                }
                timeline.actions.append(.init(index: index, startAt: startAt, endAt: Self.now(), ok: true, error: nil))
            } catch {
                timeline.actions.append(.init(index: index, startAt: startAt, endAt: Self.now(), ok: false, error: "\(error)"))
                try write(timeline, to: job.timelinePath)
                XCTFail("CAPTURE: ✗ action \(index + 1) (\(action.type)): \(error)")
                return
            }
        }
        // Keep recording through the settle window the worker may trim to (D9).
        Thread.sleep(forTimeInterval: job.tailMs / 1000)
        try write(timeline, to: job.timelinePath)
        print("CAPTURE: ✓ recorded \(job.actions.count) action(s) of \(job.view)")
    }

    /// D8: one card. Every type but `wait` targets an element; a missing one fails the card (F2).
    @MainActor
    private func perform(_ action: RecordingJob.Action, in app: XCUIApplication, timeline: inout Timeline) throws {
        if action.type == "wait" {
            Thread.sleep(forTimeInterval: (action.durationMs ?? 0) / 1000)
            return
        }
        guard let name = action.element, !name.isEmpty else { throw RecordingFailure("\(action.type) names no element") }
        let target = resolve(app, name, fallbacks: action.fallbacks ?? [])
        if action.type == "scroll_to" {
            var swipes = 0
            while !(target.exists && target.isHittable) && swipes < 12 {
                app.swipeUp(velocity: .slow)
                swipes += 1
            }
            guard target.exists && target.isHittable else { throw RecordingFailure("no element named \"\(name)\" came into view") }
            if timeline.elements[name] == nil { timeline.elements[name] = rect(target.frame) }
            return
        }
        // `exists` first: waitForExistence costs ~1 s even when the element is already there.
        guard target.exists || target.waitForExistence(timeout: 5) else {
            // Say what IS there, so a missing name is diagnosable from the log (d2m stores the last line).
            print("CAPTURE: on screen: \(identifiers(app).joined(separator: ", "))")
            throw RecordingFailure("no element named \"\(name)\" on screen")
        }
        // An earlier card may have scrolled this one off screen (XCUITest scrolls to make its own
        // target hittable): scroll back toward it, up to six swipes, before acting.
        bringIntoView(target, in: app)
        if timeline.elements[name] == nil { timeline.elements[name] = rect(target.frame) }
        switch action.type {
        case "tap": target.tap()
        case "long_press": target.press(forDuration: (action.holdMs ?? 800) / 1000)
        case "type_text":
            target.tap()
            app.typeText(action.text ?? "")
        case "swipe":
            switch action.direction {
            case "up": target.swipeUp()
            case "down": target.swipeDown()
            case "left": target.swipeLeft()
            case "right": target.swipeRight()
            default: throw RecordingFailure("swipe needs a direction (up, down, left or right)")
            }
        default: throw RecordingFailure("unknown action type \(action.type)")
        }
    }

    /// The card's element, or — when its name is not exposed because an outer `.ui2Element` on the same
    /// view replaced it — the first enclosing element d2m named that is (same centre, same gesture).
    @MainActor
    private func resolve(_ app: XCUIApplication, _ name: String, fallbacks: [String]) -> XCUIElement {
        let target = element(app, name)
        if target.exists || fallbacks.isEmpty { return target }
        // The screen may still be settling: watch the name and its fallbacks together for up to 5 s.
        let deadline = Date().addingTimeInterval(5)
        repeat {
            if target.exists { return target }
            for other in fallbacks {
                let candidate = element(app, other)
                if candidate.exists {
                    print("CAPTURE: \"\(name)\" is not exposed on screen — using \"\(other)\", which encloses it")
                    return candidate
                }
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return target
    }

    /// Swipe toward an element that exists but sits off screen: the page up or down when it is above or
    /// below, the smallest scroll view holding it left or right when it is past a side (a rail).
    @MainActor
    private func bringIntoView(_ target: XCUIElement, in app: XCUIApplication) {
        let screen = app.frame
        let id = target.identifier
        var swipes = 0
        while !target.isHittable && swipes < 8 {
            let f = target.frame
            if f.maxY <= screen.minY + 60 { app.swipeDown(velocity: .slow) }
            else if f.minY >= screen.maxY - 60 { app.swipeUp(velocity: .slow) }
            else if f.minX >= screen.maxX - 20 || f.maxX <= screen.minX + 20 {
                let rails = app.scrollViews.containing(.any, identifier: id).allElementsBoundByIndex
                    .filter { $0.exists }.sorted { $0.frame.height < $1.frame.height }
                guard let rail = rails.first else { break }
                if f.minX >= screen.maxX - 20 { rail.swipeLeft(velocity: .slow) } else { rail.swipeRight(velocity: .slow) }
            } else { break }
            swipes += 1
        }
    }

    /// Every accessibility identifier on screen, once each, in tree order — the failure log's hint.
    @MainActor
    private func identifiers(_ app: XCUIApplication) -> [String] {
        var seen = Set<String>()
        return app.descendants(matching: .any).allElementsBoundByIndex.compactMap { el in
            let id = el.identifier
            return id.isEmpty || !seen.insert(id).inserted ? nil : id
        }
    }

    /// D25: a name may match several elements — the first is used.
    @MainActor
    private func element(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: name).firstMatch
    }

    private func rect(_ frame: CGRect) -> Timeline.Rect {
        .init(x: Double(frame.minX), y: Double(frame.minY), w: Double(frame.width), h: Double(frame.height))
    }

    private func waitForReport(_ job: RecordingJob, seconds: TimeInterval, until done: (AppReport) -> Bool) throws -> AppReport {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if let data = FileManager.default.contents(atPath: job.appReportPath),
               let report = try? JSONDecoder().decode(AppReport.self, from: data),
               done(report) {
                return report
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        throw RecordingFailure("the capture app did not answer within \(Int(seconds)) s (\(job.appReportPath))")
    }

    private func write(_ timeline: Timeline, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(timeline).write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

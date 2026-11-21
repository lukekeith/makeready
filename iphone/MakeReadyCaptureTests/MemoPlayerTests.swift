//
//  MemoPlayerTests.swift
//  MakeReadyCaptureTests
//
//  `MemoPlayer` driven by a spy backend and a spy audio session, never AVPlayer or the real
//  session (D13): seek clamping, the expired-URL and 403 re-fetches, local playback and the
//  session restore on stop.
//

import XCTest
@testable import MakeReady

@MainActor
private final class PlayerSpyBackend: MemoPlaybackBackend {
    var onFailure: ((Int?) -> Void)?
    var currentTime: Double = 0
    private(set) var loaded: [URL] = []
    private(set) var seeks: [Double] = []
    private(set) var plays = 0
    private(set) var pauses = 0

    func load(url: URL) { loaded.append(url) }
    func play() { plays += 1 }
    func pause() { pauses += 1 }
    func seek(to seconds: Double) { seeks.append(seconds) }
}

@MainActor
private final class PlayerSpySession: MemoPlaybackSessionControlling {
    private(set) var calls: [String] = []

    func activatePlayback() throws { calls.append("activatePlayback") }
    func restore() { calls.append("restore") }
}

@MainActor
final class MemoPlayerTests: XCTestCase {
    private let clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var currentDate = Date(timeIntervalSince1970: 1_800_000_000)
    private var backend: PlayerSpyBackend!
    private var session: PlayerSpySession!
    private var fetches = 0

    override func setUp() {
        super.setUp()
        backend = PlayerSpyBackend()
        session = PlayerSpySession()
        fetches = 0
        currentDate = clock
    }

    // MARK: - Helpers

    private func makePlayer(fetch: @escaping (String) async throws -> VoiceMemo = { _ in
        throw URLError(.badServerResponse)
    }) -> MemoPlayer {
        MemoPlayer(backend: backend, session: session,
                   fetchDetail: { [unowned self] id in
                       fetches += 1
                       return try await fetch(id)
                   },
                   now: { [unowned self] in currentDate })
    }

    private func memo(url: String?, expires: Date?, durationMs: Int = 60_000) -> VoiceMemo {
        VoiceMemo(id: "memo-1", title: "Memo", url: url, urlExpiresAt: expires, mimeType: "audio/mp4",
                  fileSize: nil, durationMs: durationMs, waveformPeaks: nil, transcript: nil,
                  transcriptSegments: nil, transcriptStatus: .none, transcriptSource: nil,
                  uploadStatus: .ready, recordedAt: clock, createdAt: clock, updatedAt: clock)
    }

    /// Waits for an async effect to land, up to a second, instead of sleeping a fixed time.
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    // MARK: - Tests

    func testSkipClampsToBounds() async {
        let player = makePlayer()
        await player.load(.local(url: URL(fileURLWithPath: "/tmp/a.m4a"), durationMs: 20_000))
        player.skip(by: -15); XCTAssertEqual(backend.seeks.last, 0)
        player.seek(to: 10); player.skip(by: 15); XCTAssertEqual(backend.seeks.last, 20)
    }

    func testExpiredURLIsRefetched() async {
        let player = makePlayer(fetch: { _ in self.memo(url: "https://r2/fresh", expires: self.clock.addingTimeInterval(3600)) })
        await player.load(.remote(memo(url: "https://r2/old", expires: clock.addingTimeInterval(-1))))
        XCTAssertEqual(fetches, 1)
        XCTAssertEqual(backend.loaded.last?.absoluteString, "https://r2/fresh")
    }

    func testA403RefetchesOnceAndReloadsAtTheSamePosition() async {
        let player = makePlayer(fetch: { _ in self.memo(url: "https://r2/fresh", expires: self.clock.addingTimeInterval(3600)) })
        await player.load(.remote(memo(url: "https://r2/old", expires: clock.addingTimeInterval(3600))))
        XCTAssertEqual(fetches, 0)
        player.seek(to: 12)
        backend.currentTime = 0  // a failed item reads 0
        backend.onFailure?(403)
        await eventually { fetches == 1 && backend.loaded.count == 2 }
        XCTAssertEqual(fetches, 1)
        XCTAssertEqual(backend.loaded.last?.absoluteString, "https://r2/fresh")
        XCTAssertEqual(backend.seeks.last, 12)
        backend.onFailure?(403); try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(fetches, 1, "a second 403 must not loop")
    }

    func testAnExpiredURLAtPlayIsRefetchedBeforePlaying() async {
        let player = makePlayer(fetch: { _ in self.memo(url: "https://r2/fresh", expires: self.clock.addingTimeInterval(7200)) })
        await player.load(.remote(memo(url: "https://r2/old", expires: clock.addingTimeInterval(3600))))
        XCTAssertEqual(fetches, 0)
        currentDate = clock.addingTimeInterval(3601)
        player.play()
        player.play()  // a second tap must not start a second fetch
        await eventually { backend.plays == 1 }
        XCTAssertEqual(fetches, 1)
        XCTAssertEqual(backend.loaded.last?.absoluteString, "https://r2/fresh")
        XCTAssertEqual(backend.plays, 1)
    }

    func testAQueuedMemoPlaysFromTheLocalFile() async {
        let player = makePlayer()
        await player.load(.local(url: URL(fileURLWithPath: "/tmp/q.m4a"), durationMs: 5_000))
        XCTAssertEqual(backend.loaded.last, URL(fileURLWithPath: "/tmp/q.m4a"))
        XCTAssertEqual(player.duration, 5)
        XCTAssertTrue(player.isReady)
    }

    func testIsNotReadyUntilTheBackendHasAnItem() async {
        let player = makePlayer()
        XCTAssertFalse(player.isReady)
        await player.load(.remote(memo(url: nil, expires: nil)))
        XCTAssertFalse(player.isReady, "a memo with no url never reaches the backend")
        XCTAssertTrue(backend.loaded.isEmpty)
    }

    func testStopRestoresTheAudioSession() {
        let player = makePlayer()
        player.play(); player.stop()
        XCTAssertEqual(session.calls, ["activatePlayback", "restore"])
        XCTAssertFalse(player.isPlaying)
    }
}

//
//  VideoReviewPlayerTests.swift
//  MakeReadyCaptureTests
//
//  The review player as the editor drives it (video-editor D20, D22, D23): pause, seek, time, the
//  end, and layers drawn into the picture.
//

import AVFoundation
import XCTest
@testable import MakeReady

@MainActor
private final class QuietSession: MemoPlaybackSessionControlling {
    func activatePlayback() throws {}
    func restore() {}
}

@MainActor
final class VideoReviewPlayerTests: XCTestCase {
    private var p: VideoReviewPlayer!
    private let area = CGRect(x: 0.45, y: 0.24, width: 0.1, height: 0.02)

    override func setUp() async throws {
        p = VideoReviewPlayer(session: QuietSession())
    }

    override func tearDown() async throws {
        p.stop()
    }

    /// Polls every 20 ms for at most 5 s.
    private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<250 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("timed out")
    }

    private func middle(_ player: VideoReviewPlayer) async throws -> TestMovie.Colour {
        try await TestMovie.itemColour(of: XCTUnwrap(player.item), at: 1, in: area)
    }

    private var block: VideoLayer {
        var style = VideoLayerStyle.standard
        style.colour = "#FF0000"
        style.size = 60
        return VideoLayer(kind: .text, text: "████", style: style, centre: CGPoint(x: 0.5, y: 0.25), startMs: 0, endMs: 2000)
    }

    // MARK: time, seek, pause and the end count from the window's start (D20, D23)

    func testDriving() async throws {
        let clip = try await TestMovie.make(seconds: 4, colour: .blue, size: CGSize(width: 540, height: 960))
        var ends = 0
        p.loops = false
        p.autoplays = false
        p.onEnd = { ends += 1 }
        try await p.load(clips: [clip], window: 1...3, look: VideoLook())

        p.seek(to: 1.5)
        try await until { abs(p.currentTime - 1.5) < 0.05 }
        XCTAssertEqual(try XCTUnwrap(p.item).currentTime().seconds, 2.5, accuracy: 0.05)
        p.play(); p.pause()
        let held = p.currentTime
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(p.currentTime, held, accuracy: 0.05)
        p.play()
        try await until { ends == 1 }
        XCTAssertEqual(p.currentTime, 2, accuracy: 0.1)
        p.play()
        try await until { p.currentTime < 1 }
    }

    // MARK: layers shown before a load are drawn (D23)

    func testShowsLayers() async throws {
        let clip = try await TestMovie.make(seconds: 2, colour: .blue, size: CGSize(width: 540, height: 960))
        p.show(layers: [block]); try await p.load(clips: [clip], window: nil, look: VideoLook())
        let drawn = try await middle(p); p.show(layers: [])
        let bare = try await middle(p)
        XCTAssertEqual([drawn, bare], [.red, .blue])
    }
}

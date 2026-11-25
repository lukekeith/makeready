//
//  AVVideoPlayerTests.swift
//  MakeReadyCaptureTests
//
//  video-activity-basics D12, D13: the mute hook, the end of a video and the gravity. The real player runs
//  muted on a file that is not there, so nothing plays and the session fake counts every touch.
//

import AVFoundation
import XCTest
@testable import MakeReady

@MainActor
private final class CountingSession: MemoPlaybackSessionControlling {
    private(set) var calls = 0
    func activatePlayback() throws { calls += 1 }
    func restore() { calls += 1 }
}

@MainActor
final class AVVideoPlayerTests: XCTestCase {
    private let session = CountingSession()
    private let url = URL(fileURLWithPath: "/nonexistent/video-activity-basics.mp4")

    func testMutedNeverTouchesTheSession() {
        let player = AVVideoPlayer(session: session, muted: true)
        player.load(url: url, duration: 10)
        player.play()
        player.stop()
        XCTAssertTrue(player.isMuted)
        XCTAssertEqual(session.calls, 0)
    }

    func testPlayAfterTheEndStartsOverWithNoDuration() {
        let player = AVVideoPlayer(session: session, muted: true)
        player.load(url: url, duration: 0)
        player.seek(to: 5)
        player.playedToEnd()
        XCTAssertEqual([player.isAtEnd, player.isPlaying], [true, false])
        XCTAssertEqual(player.elapsed, 5)
        player.play()
        XCTAssertFalse(player.isAtEnd)
        XCTAssertEqual(player.elapsed, 0)
        player.playedToEnd()
        player.seek(to: 2)
        XCTAssertFalse(player.isAtEnd)
        player.stop()
    }

    func testGravityDefaultsToFit() {
        func gravity(_ player: AVVideoPlayer) -> AVLayerVideoGravity? { (player.layer as? AVPlayerLayer)?.videoGravity }
        XCTAssertEqual(gravity(AVVideoPlayer(muted: true)), .resizeAspect)
        XCTAssertEqual(gravity(AVVideoPlayer(videoGravity: .resizeAspectFill, muted: true)), .resizeAspectFill)
    }

    func testTheLaunchArgumentMutes() {
        UserDefaults.standard.set(true, forKey: "muteVideoPlayback")
        defer { UserDefaults.standard.removeObject(forKey: "muteVideoPlayback") }
        XCTAssertTrue(AVVideoPlayer().isMuted)
    }
}

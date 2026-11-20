//
//  MemoAudioSession.swift
//  MakeReady
//
//  The audio-session handshake behind a protocol so tests never touch the real session (D20):
//  `prepareForRecording` remembers what the app had and sets `.playAndRecord`/`.spokenAudio`,
//  `activate` turns it on, `restore` hands back the remembered category so playback elsewhere
//  (the viewer's `AVPlayer`) is unaffected.
//

import AVFoundation

protocol MemoAudioSessionControlling: AnyObject {
    func prepareForRecording() throws
    func activate() throws
    func restore()
}

final class MemoAudioSession: MemoAudioSessionControlling {
    private struct Saved {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
    }

    private let session: AVAudioSession
    private var saved: Saved?

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    func prepareForRecording() throws {
        saved = Saved(category: session.category, mode: session.mode, options: session.categoryOptions)
        try session.setCategory(.playAndRecord, mode: .spokenAudio)
    }

    func activate() throws {
        try session.setActive(true)
    }

    func restore() {
        guard let saved else { return }
        self.saved = nil
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(saved.category, mode: saved.mode, options: saved.options)
        } catch {
            // Recovered: the memo is already written; the next playback sets its own category.
            Log.memo.error("audio session not restored: \(error.localizedDescription)")
        }
    }
}

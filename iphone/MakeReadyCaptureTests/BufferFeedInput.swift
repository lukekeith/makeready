//
//  BufferFeedInput.swift
//  MakeReadyCaptureTests
//
//  A test `AudioInputSource`: on `start` it synchronously hands the engine the fixture buffers it
//  was built with, and `feed(_:)` hands over more. No microphone, no AVAudioEngine (F4).
//

import AVFoundation
@testable import MakeReady

final class BufferFeedInput: AudioInputSource {
    let format: AVAudioFormat
    private let initial: [AVAudioPCMBuffer]
    private var handler: ((AVAudioPCMBuffer) -> Void)?
    private(set) var stopCount = 0

    init(format: AVAudioFormat, initial: [AVAudioPCMBuffer] = []) {
        self.format = format
        self.initial = initial
    }

    func start(_ onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
        handler = onBuffer
        initial.forEach(onBuffer)
    }

    func stop() {
        stopCount += 1
        handler = nil
    }

    /// Hands `buffers` to the engine now, as the tap would. Dropped when the input is stopped.
    func feed(_ buffers: [AVAudioPCMBuffer]) {
        buffers.forEach { handler?($0) }
    }
}

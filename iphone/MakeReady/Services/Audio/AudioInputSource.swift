//
//  AudioInputSource.swift
//  MakeReady
//
//  Where the recorder engine's PCM comes from: the microphone tap in the app, a buffer feeder in
//  tests (the headless simulator may have no audio input, F4).
//

import AVFoundation

protocol AudioInputSource: AnyObject {
    /// The format of the buffers handed to `start`'s callback.
    var format: AVAudioFormat { get }
    /// Begins delivering buffers. The callback may run on any thread; a buffer is only valid for
    /// the duration of the call.
    func start(_ onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws
    func stop()
}

/// The microphone: a tap on `AVAudioEngine.inputNode` bus 0, 4 096 frames per buffer (D14).
/// The caller owns the `AVAudioSession` (category, activation, D20).
final class LiveAudioInput: AudioInputSource {
    static let tapFrames: AVAudioFrameCount = 4_096

    private let engine = AVAudioEngine()

    var format: AVAudioFormat { engine.inputNode.outputFormat(forBus: 0) }

    func start(_ onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
        let node = engine.inputNode
        node.installTap(onBus: 0, bufferSize: Self.tapFrames, format: node.outputFormat(forBus: 0)) { buffer, _ in
            onBuffer(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            node.removeTap(onBus: 0)
            throw error
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// True when the microphone is, or becomes by the user's answer, authorized.
    static func requestPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        default: return await AVAudioApplication.requestRecordPermission()
        }
    }
}

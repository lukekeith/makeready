//
//  MemoAudioFixtures.swift
//  MakeReadyCaptureTests
//
//  Synthetic PCM for the voice-memo engine tests: a mono float32 440 Hz sine, as a temp `.caf`
//  or as in-memory buffers.
//

import AVFoundation
import XCTest

enum MemoAudioFixtures {
    static let frequency = 440.0

    /// Writes `seconds` of a mono float32 440 Hz sine to a fresh temp `.caf` and returns its URL.
    static func sineCAF(seconds: Double, sampleRate: Double = 44_100) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memo-sine-\(UUID().uuidString).caf")
        let format = try makeFormat(sampleRate: sampleRate)
        let file = try AVAudioFile(forWriting: url, settings: format.settings,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
        for buffer in try sineBuffers(seconds: seconds, sampleRate: sampleRate, frames: 4096) {
            try file.write(from: buffer)
        }
        return url
    }

    /// `seconds` of the sine as consecutive buffers of at most `frames` frames. Phase runs on
    /// across buffers, so concatenating them is one unbroken tone.
    static func sineBuffers(seconds: Double, sampleRate: Double = 44_100,
                            frames: AVAudioFrameCount = 4096) throws -> [AVAudioPCMBuffer] {
        let format = try makeFormat(sampleRate: sampleRate)
        let total = Int((seconds * sampleRate).rounded())
        var buffers: [AVAudioPCMBuffer] = []
        var written = 0
        while written < total {
            let count = min(Int(frames), total - written)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
                  let channel = buffer.floatChannelData?[0] else {
                throw FixtureError.bufferAllocationFailed
            }
            buffer.frameLength = AVAudioFrameCount(count)
            for i in 0..<count {
                let phase = 2 * Double.pi * frequency * Double(written + i) / sampleRate
                channel[i] = Float(sin(phase))
            }
            buffers.append(buffer)
            written += count
        }
        return buffers
    }

    enum FixtureError: Error {
        case formatUnavailable
        case bufferAllocationFailed
    }

    private static func makeFormat(sampleRate: Double) throws -> AVAudioFormat {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                                         channels: 1, interleaved: false) else {
            throw FixtureError.formatUnavailable
        }
        return format
    }
}

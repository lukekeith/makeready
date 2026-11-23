//
//  CountdownBeeper.swift
//  MakeReady
//
//  The pre-roll countdown's beep (video-recorder D2): a short sine tone, made in memory and played
//  through the capture session's audio session.
//

import AVFoundation

@MainActor
final class CountdownBeeper {
    private static let sampleRate = 44_100
    private static let seconds = 0.12
    private static let amplitude = 0.4
    /// The tone fades at both ends over this long, so it does not click.
    private static let fadeSeconds = 0.01

    private var players: [Double: AVAudioPlayer] = [:]

    func beep(hz: Double) {
        do {
            let player = try players[hz] ?? AVAudioPlayer(data: Self.wav(hz: hz))
            players[hz] = player
            player.currentTime = 0
            player.play()
        } catch {
            // Recovered: the numerals still count down without the beep.
            Log.media.error("countdown beep not playable: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// A 16-bit mono WAV file of one tone.
    static func wav(hz: Double) -> Data {
        let count = Int(Double(sampleRate) * seconds)
        var samples = Data(capacity: count * 2)
        for index in 0..<count {
            let time = Double(index) / Double(sampleRate)
            let fade = min(1, time / fadeSeconds, (seconds - time) / fadeSeconds)
            let value = sin(2 * .pi * hz * time) * amplitude * fade
            append(Int16(value * Double(Int16.max)), to: &samples)
        }
        var file = Data("RIFF".utf8)
        append(UInt32(36 + samples.count), to: &file)
        file += Data("WAVEfmt ".utf8)
        append(UInt32(16), to: &file)                   // format chunk size
        append(UInt16(1), to: &file)                    // PCM
        append(UInt16(1), to: &file)                    // mono
        append(UInt32(sampleRate), to: &file)
        append(UInt32(sampleRate * 2), to: &file)       // bytes per second
        append(UInt16(2), to: &file)                    // bytes per frame
        append(UInt16(16), to: &file)                   // bits per sample
        file += Data("data".utf8)
        append(UInt32(samples.count), to: &file)
        return file + samples
    }

    private static func append<Value: FixedWidthInteger>(_ value: Value, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}

//
//  CountdownBeeper.swift
//  MakeReady
//
//  The pre-roll countdown's beep (video-recorder D2): a short sine tone, made in memory. It sounds
//  only when the recorder's countdown Sound setting is on (off by default), and it plays as a system
//  sound, so the phone's ring/silent switch mutes it (countdown-sound S1–S3, owner 2026-11-24).
//

import AudioToolbox
import Foundation

@MainActor
final class CountdownBeeper {
    private static let sampleRate = 44_100
    private static let seconds = 0.12
    private static let amplitude = 0.4
    /// The tone fades at both ends over this long, so it does not click.
    private static let fadeSeconds = 0.01

    private let isSoundOn: () -> Bool
    private let play: (Double) -> Void

    /// `isSoundOn` reads the recorder's Sound setting each beep, so a change applies at once.
    init(isSoundOn: @escaping () -> Bool = { RecorderSettings().countdownSound },
         play: ((Double) -> Void)? = nil) {
        self.isSoundOn = isSoundOn
        self.play = play ?? SystemTone().play(hz:)
    }

    func beep(hz: Double) {
        guard isSoundOn() else { return }
        play(hz)
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

/// One registered system sound per pitch. System sounds play at the ringer volume and are silenced by
/// the ring/silent switch, unlike the capture session's audio session.
@MainActor
private final class SystemTone {
    private var sounds: [Double: SystemSoundID] = [:]

    func play(hz: Double) {
        if let id = sounds[hz] {
            AudioServicesPlaySystemSound(id)
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("countdown-\(Int(hz)).wav")
        do {
            try CountdownBeeper.wav(hz: hz).write(to: url, options: .atomic)
        } catch {
            // Recovered: the numerals still count down without the beep.
            Log.media.error("countdown beep not written: \(error.localizedDescription, privacy: .public)")
            return
        }
        var id: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(url as CFURL, &id)
        guard status == kAudioServicesNoError else {
            // Recovered: the numerals still count down without the beep.
            Log.media.error("countdown beep not registered: \(status, privacy: .public)")
            return
        }
        sounds[hz] = id
        AudioServicesPlaySystemSound(id)
    }
}

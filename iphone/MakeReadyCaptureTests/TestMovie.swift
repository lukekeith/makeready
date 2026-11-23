//
//  TestMovie.swift
//  MakeReadyCaptureTests
//
//  Synthetic clips written with `AVAssetWriter`, and readers for what an export drew. No camera.
//

import AVFoundation
import CoreGraphics
import Foundation

enum TestMovie {
    enum Colour: Equatable {
        case red, green, blue, grey

        fileprivate var bgra: [UInt8] {
            switch self {
            case .red: return [0, 0, 255, 255]
            case .green: return [0, 255, 0, 255]
            case .blue: return [255, 0, 0, 255]
            case .grey: return [128, 128, 128, 255]
            }
        }
    }

    enum Failure: Error {
        case writing, reading
    }

    private static let frameRate = 30
    private static let sampleRate = 44_100

    /// A clip of one colour, or of two halves when `rightHalf` is given, with a tone unless `audio` is
    /// false. `size` is the stored pixels' size, before `transform`.
    static func make(seconds: Int, colour: Colour, size: CGSize, rightHalf: Colour? = nil,
                     transform: CGAffineTransform = .identity, audio: Bool = true) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TestMovie-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size.width, AVVideoHeightKey: size.height
        ])
        video.transform = transform
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: nil)
        let tone = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: 1
        ])
        writer.add(video)
        if audio { writer.add(tone) }
        guard writer.startWriting() else { throw writer.error ?? Failure.writing }
        writer.startSession(atSourceTime: .zero)
        let picture = try pixels(size: size, left: colour, right: rightHalf ?? colour)
        // Either input may wait for the other's samples, so feed whichever is ready.
        let frames = seconds * frameRate
        var pictures = 0, tones = audio ? 0 : frames, idle = 0
        while pictures < frames || tones < frames {
            let before = pictures + tones
            if pictures < frames, video.isReadyForMoreMediaData {
                adaptor.append(picture, withPresentationTime: CMTime(value: CMTimeValue(pictures), timescale: CMTimeScale(frameRate)))
                pictures += 1
                if pictures == frames { video.markAsFinished() }
            }
            if tones < frames, tone.isReadyForMoreMediaData {
                tone.append(try toneBuffer(frame: tones))
                tones += 1
                if tones == frames { tone.markAsFinished() }
            }
            idle = pictures + tones == before ? idle + 1 : 0
            guard idle < 5_000, writer.status == .writing else { throw writer.error ?? Failure.writing }
            if idle > 0 { try await Task.sleep(for: .milliseconds(2)) }
        }
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(seconds), timescale: 1))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? Failure.writing }
        return url
    }

    /// The colour shown, upright, at `seconds` within `area` (unit square, origin top-left).
    static func dominantColour(of url: URL, at seconds: Double,
                               in area: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) async throws -> Colour {
        let (r, g, b) = try await meanRGB(of: url, at: seconds, in: area)
        let channels = [r, g, b]
        guard let high = channels.max(), let low = channels.min(), high - low > 40 else { return .grey }
        return high == r ? .red : (high == g ? .green : .blue)
    }

    static func meanRGB(of url: URL, at seconds: Double,
                        in area: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) async throws -> (Int, Int, Int) {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let frame = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        let rect = CGRect(x: area.minX * CGFloat(frame.width), y: area.minY * CGFloat(frame.height),
                          width: area.width * CGFloat(frame.width), height: area.height * CGFloat(frame.height))
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let cropped = frame.cropping(to: rect.integral),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.reading }
        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }

    /// The size the first video track is shown at, its `preferredTransform` applied.
    static func naturalPortraitSize(of url: URL) async throws -> CGSize {
        guard let track = try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first else { throw Failure.reading }
        let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
        let shown = CGRect(origin: .zero, size: size).applying(transform)
        return CGSize(width: shown.width, height: shown.height)
    }

    /// The four-character codes of a media type's formats.
    static func codecs(of url: URL, _ type: AVMediaType) async throws -> [FourCharCode] {
        var codes: [FourCharCode] = []
        for track in try await AVURLAsset(url: url).loadTracks(withMediaType: type) {
            codes += try await track.load(.formatDescriptions).map { CMFormatDescriptionGetMediaSubType($0) }
        }
        return codes
    }

    // MARK: Writing

    private static func pixels(size: CGSize, left: Colour, right: Colour) throws -> CVPixelBuffer {
        let width = Int(size.width), height = Int(size.height)
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        guard let buffer else { throw Failure.writing }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw Failure.writing }
        let row = (0..<width).flatMap { $0 < width / 2 ? left.bgra : right.bgra }
        for y in 0..<height {
            row.withUnsafeBytes { bytes in
                guard let source = bytes.baseAddress else { return }
                memcpy(base + y * CVPixelBufferGetBytesPerRow(buffer), source, bytes.count)
            }
        }
        return buffer
    }

    private static func toneBuffer(frame: Int) throws -> CMSampleBuffer {
        let count = sampleRate / frameRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1),
              let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let samples = pcm.floatChannelData?[0] else { throw Failure.writing }
        pcm.frameLength = AVAudioFrameCount(count)
        for i in 0..<count {
            samples[i] = 0.2 * sin(Float(frame * count + i) * 2 * .pi * 440 / Float(sampleRate))
        }
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)),
            presentationTimeStamp: CMTime(value: CMTimeValue(frame * count), timescale: CMTimeScale(sampleRate)),
            decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreate(allocator: nil, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil,
                             formatDescription: format.formatDescription, sampleCount: count, sampleTimingEntryCount: 1,
                             sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample)
        guard let sample,
              CMSampleBufferSetDataBufferFromAudioBufferList(
                sample, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0,
                bufferList: pcm.audioBufferList) == noErr else { throw Failure.writing }
        return sample
    }
}

//
//  VideoExporterTests.swift
//  MakeReadyCaptureTests
//
//  The exported file (video-recorder D6, D8, D13): order, length, size, orientation and filter.
//

import AVFoundation
import CoreImage
import MakeReadyUI
import XCTest
@testable import MakeReady

@MainActor
final class VideoExporterTests: XCTestCase {
    private var dir: URL!

    /// Portrait pixels stored rotated, as the camera stores them (landscape, shown turned 90° clockwise).
    private let sensor = CGSize(width: 640, height: 360)
    private let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 360, ty: 0)
    private let counterTurn = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 640)
    private let top = CGRect(x: 0.25, y: 0.1, width: 0.5, height: 0.2)
    private let bottom = CGRect(x: 0.25, y: 0.7, width: 0.5, height: 0.2)

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("VideoExporterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: dir)
    }

    private func tmp(_ name: String) -> URL {
        dir.appendingPathComponent(name)
    }

    // MARK: two segments concatenate in order into one portrait mp4 with summed duration (D13)

    func testConcatenatesInOrder() async throws {
        let a = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 1080, height: 1920))
        let b = try await TestMovie.make(seconds: 2, colour: .blue, size: CGSize(width: 1080, height: 1920))
        let out = try await VideoExporter.export(segments: [a, b], timeRange: nil, filter: .normal, strength: 1, to: tmp("out.mp4"))
        XCTAssertEqual(out.durationSeconds, 3, accuracy: 0.2)
        let first = try await TestMovie.dominantColour(of: out.url, at: 0.5)
        let second = try await TestMovie.dominantColour(of: out.url, at: 2.0)
        let size = try await TestMovie.naturalPortraitSize(of: out.url)
        XCTAssertEqual(first, .red)
        XCTAssertEqual(second, .blue)
        XCTAssertEqual(size, CGSize(width: 1080, height: 1920))
        let videoCodecs = try await TestMovie.codecs(of: out.url, .video)
        let audioCodecs = try await TestMovie.codecs(of: out.url, .audio)
        XCTAssertTrue(Set(videoCodecs).isSubset(of: [kCMVideoCodecType_H264, kCMVideoCodecType_HEVC]))
        XCTAssertEqual(Set(audioCodecs), [kAudioFormatMPEG4AAC])
        XCTAssertNotNil(out.posterImage)
    }

    // MARK: a trim window exports only that window (D8)

    func testTrimWindow() async throws {
        let clip = try await TestMovie.make(seconds: 5, colour: .green, size: CGSize(width: 720, height: 1280))
        let range = CMTimeRange(start: .init(seconds: 1, preferredTimescale: 600), duration: .init(seconds: 2, preferredTimescale: 600))
        let out = try await VideoExporter.export(segments: [clip], timeRange: range, filter: .normal, strength: 1, to: tmp("trim.mp4"))
        XCTAssertEqual(out.durationSeconds, 2, accuracy: 0.2)
        let size = try await TestMovie.naturalPortraitSize(of: out.url)
        XCTAssertEqual(size, CGSize(width: 720, height: 1280), "a smaller source is not scaled up")
    }

    func testFilteredTrimKeepsTheWindow() async throws {
        let a = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 360, height: 640))
        let b = try await TestMovie.make(seconds: 2, colour: .blue, size: CGSize(width: 360, height: 640))
        let range = CMTimeRange(start: .init(seconds: 1, preferredTimescale: 600), duration: .init(seconds: 1, preferredTimescale: 600))
        let out = try await VideoExporter.export(segments: [a, b], timeRange: range, filter: .vivid, strength: 1, to: tmp("t.mp4"))
        XCTAssertEqual(out.durationSeconds, 1, accuracy: 0.2)
        let colour = try await TestMovie.dominantColour(of: out.url, at: 0.3)
        XCTAssertEqual(colour, .blue)
    }

    func testLargerSourceIsScaledDown() async throws {
        let clip = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 1440, height: 2560))
        let plain = try await VideoExporter.export(segments: [clip], timeRange: nil, filter: .normal, strength: 1, to: tmp("a.mp4"))
        let drawn = try await VideoExporter.export(segments: [clip], timeRange: nil, filter: .mono, strength: 1, to: tmp("b.mp4"))
        for url in [plain.url, drawn.url] {
            let size = try await TestMovie.naturalPortraitSize(of: url)
            XCTAssertEqual(size, CGSize(width: 1080, height: 1920))
        }
    }

    // MARK: orientation (D13, P10)

    func testRotatedSegmentsStayUpright() async throws {
        let clip = try await TestMovie.make(seconds: 1, colour: .red, size: sensor, rightHalf: .blue, transform: quarterTurn)
        for filter in [VideoFilter.normal, .vivid] {
            let out = try await VideoExporter.export(segments: [clip, clip], timeRange: nil, filter: filter, strength: 1,
                                                     to: tmp("\(filter.rawValue).mp4"))
            let size = try await TestMovie.naturalPortraitSize(of: out.url)
            let upper = try await TestMovie.dominantColour(of: out.url, at: 1.5, in: top)
            let lower = try await TestMovie.dominantColour(of: out.url, at: 1.5, in: bottom)
            XCTAssertEqual(size, CGSize(width: 360, height: 640), filter.rawValue)
            XCTAssertEqual(upper, .red, filter.rawValue)
            XCTAssertEqual(lower, .blue, filter.rawValue)
        }
    }

    /// The turn is drawn into the pixels, never left to the file's track transform: Cloudflare's
    /// transcode does not apply a stored rotation or mirror the way AVFoundation does, so a
    /// transform-only file played back upside down there (owner walk 2026-11-25).
    func testOrientationIsDrawnIntoThePixelsNotTheTrackTransform() async throws {
        let turned = try await TestMovie.make(seconds: 1, colour: .red, size: sensor, rightHalf: .blue, transform: quarterTurn)
        let mirrored = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 360, height: 640), rightHalf: .blue,
                                                transform: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 360, ty: 0))
        for (name, clip) in [("turned", turned), ("mirrored", mirrored)] {
            let out = try await VideoExporter.export(segments: [clip], timeRange: nil, filter: .normal, strength: 1,
                                                     to: tmp("\(name).mp4"))
            let track = try await XCTUnwrap(AVURLAsset(url: out.url).loadTracks(withMediaType: .video).first)
            let (stored, transform) = try await track.load(.naturalSize, .preferredTransform)
            XCTAssertEqual(transform, .identity, name)
            XCTAssertEqual(stored, CGSize(width: 360, height: 640), name)
        }
    }

    /// Flip between segments: each segment has its own rotation and mirroring.
    func testEachSegmentKeepsItsOwnOrientation() async throws {
        let turned = try await TestMovie.make(seconds: 1, colour: .red, size: sensor, rightHalf: .blue, transform: quarterTurn)
        let counter = try await TestMovie.make(seconds: 1, colour: .red, size: sensor, rightHalf: .blue, transform: counterTurn)
        let mirrored = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 360, height: 640), rightHalf: .blue,
                                                transform: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 360, ty: 0))
        for filter in [VideoFilter.normal, .vivid] {
            let out = try await VideoExporter.export(segments: [turned, counter, mirrored], timeRange: nil, filter: filter,
                                                     strength: 1, to: tmp("\(filter.rawValue).mp4"))
            let size = try await TestMovie.naturalPortraitSize(of: out.url)
            let first = try await TestMovie.dominantColour(of: out.url, at: 0.5, in: top)
            let second = try await TestMovie.dominantColour(of: out.url, at: 1.5, in: top)
            let third = try await TestMovie.dominantColour(of: out.url, at: 2.5, in: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.8))
            XCTAssertEqual(size, CGSize(width: 360, height: 640), filter.rawValue)
            XCTAssertEqual(first, .red, filter.rawValue)
            XCTAssertEqual(second, .blue, filter.rawValue)
            XCTAssertEqual(third, .blue, filter.rawValue)
        }
    }

    // MARK: filters (D6, P5)

    func testThereAreEightFiltersNormalFirst() {
        XCTAssertEqual(VideoFilter.allCases.count, 8)
        XCTAssertEqual(VideoFilter.allCases.first, .normal)
        XCTAssertEqual(VideoFilter.allCases.map(\.name), FilterStrip.Look.allCases.map(\.name))
    }

    func testFilterIsDrawnIntoThePixels() async throws {
        let clip = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 360, height: 640))
        let mono = try await VideoExporter.export(segments: [clip], timeRange: nil, filter: .mono, strength: 1, to: tmp("full.mp4"))
        let none = try await VideoExporter.export(segments: [clip], timeRange: nil, filter: .mono, strength: 0, to: tmp("none.mp4"))
        let full = try await TestMovie.dominantColour(of: mono.url, at: 0.5)
        let zero = try await TestMovie.dominantColour(of: none.url, at: 0.5)
        XCTAssertEqual(full, .grey)
        XCTAssertEqual(zero, .red)
    }

    func testEveryLookChangesThePictureAndStrengthBlends() throws {
        let source = CIImage(color: CIColor(red: 0.8, green: 0.4, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        let plain = pixel(source)
        XCTAssertEqual(pixel(VideoFilter.normal.apply(to: source, strength: 1)), plain)
        for filter in VideoFilter.allCases.dropFirst() {
            XCTAssertNotEqual(pixel(filter.apply(to: source, strength: 1)), plain, filter.rawValue)
            XCTAssertEqual(pixel(filter.apply(to: source, strength: 0)), plain, filter.rawValue)
        }
        let saturation = { (strength: Double) -> Int in
            let p = self.pixel(VideoFilter.mono.apply(to: source, strength: strength))
            return Int(p[0]) - Int(p[2])
        }
        XCTAssertGreaterThan(saturation(0), saturation(0.5))
        XCTAssertGreaterThan(saturation(0.5), saturation(1))
    }

    /// The preview copies the filter and sets its input image: it draws what the export draws.
    func testPreviewFilterDrawsTheSamePicture() throws {
        let source = CIImage(color: CIColor(red: 0.8, green: 0.4, blue: 0.2)).cropped(to: CGRect(x: 0, y: 0, width: 8, height: 8))
        XCTAssertNil(VideoFilter.normal.previewFilter(strength: 1))
        for filter in VideoFilter.allCases.dropFirst() {
            let copy = try XCTUnwrap(filter.previewFilter(strength: 0.6)?.copy() as? CIFilter)
            copy.setValue(source, forKey: kCIInputImageKey)
            let drawn = try XCTUnwrap(copy.outputImage)
            XCTAssertEqual(pixel(drawn), pixel(filter.apply(to: source, strength: 0.6)), filter.rawValue)
        }
    }

    // MARK: layers (video-editor D2, D20, D23)

    private let area = CGRect(x: 0.45, y: 0.24, width: 0.1, height: 0.02)

    private func red(_ start: Int, _ end: Int) -> VideoLayer {
        var style = VideoLayerStyle.standard
        style.colour = "#FF0000"
        style.size = 60
        return VideoLayer(kind: .text, text: "████", style: style, centre: CGPoint(x: 0.5, y: 0.25), startMs: start, endMs: end)
    }

    func testLayersAreDrawnInTheirWindow() async throws {
        let clip = try await TestMovie.make(seconds: 3, colour: .blue, size: CGSize(width: 540, height: 960))
        let out = try await VideoExporter.export(segments: [clip], timeRange: nil, filter: .normal, strength: 1,
                                                 layers: [red(1000, 2000)], to: tmp("layers.mp4"))
        for (seconds, colour) in [(0.5, TestMovie.Colour.blue), (1.5, .red), (2.5, .blue)] {
            let shown = try await TestMovie.dominantColour(of: out.url, at: seconds, in: area)
            XCTAssertEqual(shown, colour, "at \(seconds)")
        }
    }

    func testLayerTimesCountFromTheWindow() async throws {
        let clip = try await TestMovie.make(seconds: 5, colour: .green, size: CGSize(width: 960, height: 540))
        let range = CMTimeRange(start: .init(seconds: 2, preferredTimescale: 600), duration: .init(seconds: 2, preferredTimescale: 600))
        let out = try await VideoExporter.export(segments: [clip], timeRange: range, filter: .vivid, strength: 1,
                                                 layers: [red(0, 1000)], to: tmp("window.mp4"))
        let early = try await TestMovie.dominantColour(of: out.url, at: 0.5, in: area)
        let late = try await TestMovie.dominantColour(of: out.url, at: 1.5, in: area)
        let frame = try await VideoExporter.frameSize(of: [clip])
        XCTAssertEqual([early, late], [.red, .green]); XCTAssertEqual(frame, CGSize(width: 960, height: 540))
    }

    func testPlayerItemDrawsTheBox() async throws {
        let clip = try await TestMovie.make(seconds: 2, colour: .blue, size: CGSize(width: 540, height: 960))
        let box = VideoLayersBox()
        let item = try await VideoExporter.playerItem(segments: [clip], look: VideoLookBox(), layers: box)
        let size = try await VideoExporter.frameSize(of: [clip])
        let itemColour = { try await TestMovie.itemColour(of: item, at: 1, in: self.area) }
        let before = try await itemColour()
        box.drawn = VideoLayerRenderer().drawn([red(0, 2000)], frame: size)
        let after = try await itemColour()
        XCTAssertEqual([before, after], [.blue, .red])
    }

    // MARK: files

    func testSilentSegmentKeepsTheLaterAudioInPlace() async throws {
        let silent = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 360, height: 640), audio: false)
        let spoken = try await TestMovie.make(seconds: 1, colour: .blue, size: CGSize(width: 360, height: 640))
        let out = try await VideoExporter.export(segments: [silent, spoken], timeRange: nil, filter: .normal, strength: 1, to: tmp("out.mp4"))
        XCTAssertEqual(out.durationSeconds, 2, accuracy: 0.2)
        let audioURL = tmp("audio.m4a")
        try await MemoAudioExporter.exportM4A(from: out.url, to: audioURL)
        let file = try AVAudioFile(forReading: audioURL)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        let rate = Int(file.processingFormat.sampleRate)
        let peak = { (range: Range<Int>) in range.map { abs(samples[$0]) }.max() ?? 0 }
        XCTAssertGreaterThan(Int(buffer.frameLength), rate * 8 / 5)
        XCTAssertLessThan(peak(0..<(rate * 4 / 5)), 0.01)
        XCTAssertGreaterThan(peak((rate * 6 / 5)..<(rate * 8 / 5)), 0.05)
    }

    /// The transcriber reads the export through `MemoAudioExporter` (D10).
    func testJoinedAudioCanBeExtracted() async throws {
        let clip = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 360, height: 640))
        let out = try await VideoExporter.export(segments: [clip, clip], timeRange: nil, filter: .normal, strength: 1, to: tmp("out.mp4"))
        try await MemoAudioExporter.exportM4A(from: out.url, to: tmp("audio.m4a"))
        let file = try AVAudioFile(forReading: tmp("audio.m4a"))
        XCTAssertEqual(Double(file.length) / file.fileFormat.sampleRate, 2, accuracy: 0.2)
    }

    func testReplacesTheFileAlreadyThere() async throws {
        let clip = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 360, height: 640), audio: false)
        try Data([1]).write(to: tmp("out.mp4"))
        let out = try await VideoExporter.export(segments: [clip], timeRange: nil, filter: .normal, strength: 1, to: tmp("out.mp4"))
        XCTAssertEqual(out.durationSeconds, 1, accuracy: 0.2)
    }

    func testNothingToExportThrows() async throws {
        let clip = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 360, height: 640), audio: false)
        let past = CMTimeRange(start: CMTime(value: 5, timescale: 1), duration: CMTime(value: 1, timescale: 1))
        for (segments, range) in [([], nil), ([clip], past)] as [([URL], CMTimeRange?)] {
            do {
                _ = try await VideoExporter.export(segments: segments, timeRange: range, filter: .normal, strength: 1, to: tmp("out.mp4"))
                XCTFail("expected a throw")
            } catch {
                XCTAssertEqual(error as? VideoExportError, .nothingToExport)
            }
        }
    }

    // MARK: the window's sound is one m4a; silence is refused (D21)

    func testExportSound() async throws {
        let a = try await TestMovie.make(seconds: 2, colour: .red, size: CGSize(width: 360, height: 640))
        let b = try await TestMovie.make(seconds: 2, colour: .blue, size: CGSize(width: 360, height: 640))
        let window = CMTimeRange(start: CMTime(value: 1, timescale: 1), duration: CMTime(value: 2, timescale: 1))
        try await VideoExporter.exportSound(segments: [a, b], timeRange: window, to: tmp("s.m4a"))
        let asset = AVURLAsset(url: tmp("s.m4a"))
        let seconds = try await asset.load(.duration).seconds
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertEqual(seconds, 2, accuracy: 0.2)
        XCTAssertTrue(videoTracks.isEmpty)

        let silent = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 360, height: 640), audio: false)
        do {
            try await VideoExporter.exportSound(segments: [silent], timeRange: nil, to: tmp("n.m4a"))
            XCTFail("expected noSound")
        } catch {
            XCTAssertEqual(error as? VideoExportError, .noSound)
        }
    }

    private func pixel(_ image: CIImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        CIContext().render(image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(x: 4, y: 4, width: 1, height: 1),
                           format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return bytes
    }
}

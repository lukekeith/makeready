//
//  VideoLayerRendererTests.swift
//  MakeReadyCaptureTests
//
//  One renderer draws a layer for the preview and the export (video-editor D2, D17, D18, D20, D22,
//  D25).
//

import CoreImage
import XCTest
@testable import MakeReady

@MainActor
final class VideoLayerRendererTests: XCTestCase {
    /// What a pixel reads as, over black.
    private enum Swatch { case red, green, blue, other }

    private let frame = CGSize(width: 540, height: 960)
    private let context = CIContext()
    private let space = CGColorSpace(name: CGColorSpace.sRGB)!

    private var blue: CIImage {
        CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(origin: .zero, size: frame))
    }

    private var block: VideoLayer {
        var style = VideoLayerStyle.standard
        style.colour = "#FF0000"
        style.size = 60
        return VideoLayer(kind: .text, text: "████", style: style, startMs: 1000, endMs: 2000)
    }

    private func shown(_ layers: [VideoLayer], _ ms: Int) -> CIImage {
        let drawn = VideoLayerRenderer().drawn(layers, frame: frame)
        return VideoLayerRenderer.compose(drawn, over: blue, at: ms, frame: frame)
    }

    private func bytes(_ image: CIImage, _ rect: CGRect) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Int(rect.width * rect.height) * 4)
        let black = CIImage(color: .black).cropped(to: rect)
        context.render(image.composited(over: black), toBitmap: &out, rowBytes: Int(rect.width) * 4,
                       bounds: rect, format: .RGBA8, colorSpace: space)
        return out
    }

    /// The colour at a unit point of the frame, y down.
    private func px(_ image: CIImage, _ x: Double, _ y: Double) -> Swatch {
        let at = CGRect(x: (x * frame.width).rounded(), y: ((1 - y) * frame.height).rounded(), width: 1, height: 1)
        let p = bytes(image, at).map(Int.init)
        func high(_ v: Int) -> Bool { v > 200 }
        func low(_ v: Int) -> Bool { v < 55 }
        if high(p[0]), low(p[1]), low(p[2]) { return .red }
        if low(p[0]), high(p[1]), low(p[2]) { return .green }
        if low(p[0]), low(p[1]), high(p[2]) { return .blue }
        return .other
    }

    private func image(_ layer: VideoLayer, _ renderer: VideoLayerRenderer) -> CIImage {
        renderer.drawn([layer], frame: frame)[0].image
    }

    private func data(_ image: CIImage) -> [UInt8] { bytes(image, image.extent) }

    func testPlaceAndWindow() {
        var l = block; l.centre = CGPoint(x: 0.5, y: 0.2)
        XCTAssertEqual(px(shown([l], 1500), 0.5, 0.2), .red)
        XCTAssertEqual(px(shown([l], 1500), 0.5, 0.8), .blue)
        XCTAssertEqual(shown([l], 1500).extent, CGRect(origin: .zero, size: frame))
        XCTAssertEqual([999, 2000].map { px(shown([l], $0), 0.5, 0.2) }, [.blue, .blue])
    }

    func testRotationOrderAndSize() throws {
        var l = block; l.text = "████████"; l.style.size = 30; l.rotation = .pi / 4
        XCTAssertEqual(px(shown([l], 1500), 0.5 + 60 / 540, 0.5 + 60 / 960), .red, "its right end points down")
        XCTAssertEqual(px(shown([l], 1500), 0.5 + 60 / 540, 0.5 - 60 / 960), .blue)
        var green = block; green.style.colour = "#00FF00"
        XCTAssertEqual(px(shown([block, green], 1500), 0.5, 0.5), .green)
        let heights = [frame, CGSize(width: 1920, height: 1080)].map { VideoLayerRenderer().drawn([block], frame: $0)[0].image.extent.height }
        XCTAssertEqual(heights[1] / heights[0], 2, accuracy: 0.05)
    }

    func testImages() {
        var moved = block; moved.centre = CGPoint(x: 0.1, y: 0.9); moved.rotation = 1; moved.startMs = 0; moved.endMs = 500
        var reworded = block; reworded.text = "██"
        let r = VideoLayerRenderer()
        XCTAssertTrue(image(moved, r) === image(block, r)); XCTAssertFalse(image(reworded, r) === image(block, r))
        XCTAssertEqual(data(image(block, r)), data(image(block, VideoLayerRenderer())))
    }

    func testLargeScale() {
        var big = block; big.scale = 6
        XCTAssertEqual(px(shown([big], 1500), 0.5, 0.5), .red)
    }
}

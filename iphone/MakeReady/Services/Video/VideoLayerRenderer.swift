//
//  VideoLayerRenderer.swift
//  MakeReady
//
//  One renderer for a video layer, used by the preview and the export (video-editor D17, D22).
//  C-092 draws the text in viewer mode; each layer is rasterised once per look and placed on a
//  frame with Core Image (D18, D20).
//

import CoreImage
import SwiftUI

/// A layer's picture and where it goes on a frame.
struct DrawnLayer: @unchecked Sendable {
    /// The layer's text, unrotated, with its extent at the origin.
    let image: CIImage
    /// A unit point on the frame, y down.
    let centre: CGPoint
    /// Radians, clockwise.
    let rotation: Double
    let startMs: Int
    let endMs: Int
}

@MainActor
final class VideoLayerRenderer {
    /// C-092's edit slot, in wu (the width its text wraps at).
    static let editSlotWidth: CGFloat = 392
    /// The reference width one wu is measured against (D20).
    static let referenceWidth: CGFloat = 440

    /// What a layer's picture depends on (D18): the same look is drawn once.
    private struct Look: Hashable {
        let text: String
        let font: VideoLayerStyle.Font
        let weight: Int
        let size: Double
        let colour: String
        let background: VideoLayerStyle.Background
        let alignment: VideoLayerStyle.Alignment
        let scale: Double
        let width: Double
        let height: Double

        init(_ layer: VideoLayer, frame: CGSize) {
            text = layer.text
            font = layer.style.font
            weight = layer.style.weight
            size = layer.style.size
            colour = layer.style.colour
            background = layer.style.background
            alignment = layer.style.alignment
            scale = layer.scale
            width = frame.width
            height = frame.height
        }
    }

    private var images: [Look: CIImage] = [:]

    /// The layers drawn for `frame`, in order. A picture is reused until its layer's look changes.
    func drawn(_ layers: [VideoLayer], frame: CGSize) -> [DrawnLayer] {
        var kept: [Look: CIImage] = [:]
        let result = layers.compactMap { layer -> DrawnLayer? in
            let look = Look(layer, frame: frame)
            guard let image = kept[look] ?? images[look] ?? rasterise(layer, frame: frame) else { return nil }
            kept[look] = image
            return DrawnLayer(image: image, centre: layer.centre, rotation: layer.rotation,
                              startMs: layer.startMs, endMs: layer.endMs)
        }
        images = kept
        return result
    }

    /// The layer as C-092 draws it in viewer mode, in the edit slot's width and unrotated (D22).
    func view(for layer: VideoLayer) -> CanvasTextObject {
        let style = layer.style
        return CanvasTextObject(
            text: layer.text,
            mode: .viewer,
            font: Self.font(style.font),
            weight: Self.weight(style.weight),
            size: CGFloat(style.size),
            color: ActivityThumbnail.color(style.colour),
            alignment: Self.alignment(style.alignment),
            label: Self.label(style.background),
            editing: false
        )
    }

    private func rasterise(_ layer: VideoLayer, frame: CGSize) -> CIImage? {
        let pixelsPerWu = CGFloat(layer.scale) * min(frame.width, frame.height) / Self.referenceWidth
        let content = view(for: layer)
            .frame(width: Self.editSlotWidth)
            .fixedSize(horizontal: false, vertical: true)
        let renderer = ImageRenderer(content: content)
        renderer.scale = pixelsPerWu
        guard let cgImage = renderer.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }

    /// The layers visible at `ms`, in array order over `picture`, clipped to the frame (D2, D9, D25).
    /// Core Image's y axis points up, so a layer's centre is flipped and its turn reversed (D22).
    nonisolated static func compose(_ layers: [DrawnLayer], over picture: CIImage, at ms: Int, frame: CGSize) -> CIImage {
        let visible = layers.filter { $0.startMs <= ms && ms < $0.endMs }
        guard !visible.isEmpty else { return picture }
        let composed = visible.reduce(picture) { below, layer in
            let size = layer.image.extent.size
            let place = CGAffineTransform(translationX: layer.centre.x * frame.width, y: (1 - layer.centre.y) * frame.height)
                .rotated(by: -layer.rotation)
                .translatedBy(x: -size.width / 2, y: -size.height / 2)
            return layer.image.transformed(by: place).composited(over: below)
        }
        return composed.cropped(to: CGRect(origin: .zero, size: frame))
    }

    // MARK: C-092 inputs

    private static func font(_ font: VideoLayerStyle.Font) -> CanvasTextObject.Font {
        switch font {
        case .display: return .display
        case .sans: return .sans
        case .serif: return .serif
        case .mono: return .mono
        case .classic: return .classic
        }
    }

    private static func weight(_ weight: Int) -> CanvasTextObject.Weight {
        switch weight {
        case 400: return .regular
        case 500: return .medium
        default: return .bold
        }
    }

    private static func alignment(_ alignment: VideoLayerStyle.Alignment) -> CanvasTextObject.Alignment {
        switch alignment {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    private static func label(_ background: VideoLayerStyle.Background) -> CanvasTextObject.Label {
        switch background {
        case .none: return .none
        case .solidDark: return .solidDark
        case .solidLight: return .solidLight
        }
    }
}

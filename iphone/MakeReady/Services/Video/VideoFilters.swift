//
//  VideoFilters.swift
//  MakeReady
//
//  The recorder's 8 looks (video-recorder D6): one definition, drawn on the live preview and into the
//  exported file. The names and the grades are d2m's (C-150 FilterStrip).
//

import CoreImage

/// In the strip's order. The raw value is what a draft stores.
enum VideoFilter: String, CaseIterable, Codable {
    case normal, vivid, warm, cool, fade, chrome, mono, noir

    /// The name under the tile, as `FilterStrip.Look.name` spells it.
    var name: String { rawValue.capitalized }

    /// The picture with the look drawn over it. `strength` runs from 0 (untouched) to 1 (the whole look).
    func apply(to image: CIImage, strength: Double) -> CIImage {
        guard self != .normal else { return image }
        let amount = min(max(strength, 0), 1)
        return graded(image)
            .applyingFilter("CIMix", parameters: [kCIInputBackgroundImageKey: image, kCIInputAmountKey: amount])
            .cropped(to: image.extent)
    }

    /// The look as one filter, for `VideoCaptureEngine.previewFilter`; nil for Normal.
    func previewFilter(strength: Double) -> CIFilter? {
        self == .normal ? nil : VideoLookFilter(look: self, strength: strength)
    }

    private func graded(_ image: CIImage) -> CIImage {
        switch self {
        case .normal:
            return image
        case .vivid:
            return image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.35, kCIInputContrastKey: 1.08])
        case .warm:
            return Self.temperature(image, target: 5000)
        case .cool:
            return Self.temperature(image, target: 8000)
        case .fade:
            return image.applyingFilter("CIPhotoEffectFade")
        case .chrome:
            return image.applyingFilter("CIPhotoEffectChrome")
        case .mono:
            return image.applyingFilter("CIPhotoEffectMono")
        case .noir:
            return image.applyingFilter("CIPhotoEffectNoir")
        }
    }

    private static func temperature(_ image: CIImage, target: CGFloat) -> CIImage {
        image.applyingFilter("CITemperatureAndTint", parameters: [
            "inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: target, y: 0)
        ])
    }
}

/// `VideoFilter` as a `CIFilter`, which the preview copies and then feeds through `kCIInputImageKey`.
private final class VideoLookFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?

    private let look: VideoFilter
    private let strength: Double

    init(look: VideoFilter, strength: Double) {
        self.look = look
        self.strength = strength
        super.init()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var outputImage: CIImage? {
        inputImage.map { look.apply(to: $0, strength: strength) }
    }

    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = VideoLookFilter(look: look, strength: strength)
        copy.inputImage = inputImage
        return copy
    }
}

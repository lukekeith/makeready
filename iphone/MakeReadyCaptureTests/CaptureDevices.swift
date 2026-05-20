//
//  CaptureDevices.swift
//  MakeReadyCaptureTests
//
//  Device presets for screenshot capture, matching App Store size tiers.
//

import SnapshotTesting
import UIKit

enum CaptureDevice: String, CaseIterable {
    case iphoneSE = "iphone-se"
    case iphone15Pro = "iphone-15-pro"
    case iphone16ProMax = "iphone-16-pro-max"

    var config: ViewImageConfig {
        switch self {
        case .iphoneSE:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0),
                size: CGSize(width: 320, height: 568),
                traits: UITraitCollection(traitsFrom: [
                    .init(userInterfaceStyle: .dark),
                    .init(displayScale: 2.0),
                    .init(userInterfaceIdiom: .phone)
                ])
            )
        case .iphone15Pro:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                size: CGSize(width: 393, height: 852),
                traits: UITraitCollection(traitsFrom: [
                    .init(userInterfaceStyle: .dark),
                    .init(displayScale: 3.0),
                    .init(userInterfaceIdiom: .phone)
                ])
            )
        case .iphone16ProMax:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                size: CGSize(width: 440, height: 956),
                traits: UITraitCollection(traitsFrom: [
                    .init(userInterfaceStyle: .dark),
                    .init(displayScale: 3.0),
                    .init(userInterfaceIdiom: .phone)
                ])
            )
        }
    }
}

//
//  DeviceChrome.swift
//  MakeReadyCaptureTests
//
//  Renders a fake iOS status bar overlay (time, signal, wifi, battery) on top
//  of captured views. Adapts layout per device: modern iPhones use the tall
//  59pt safe-area bar (no Dynamic Island pill); iPhone SE uses the classic 20pt bar.
//
//  This is test-only code — the app itself is never modified.
//

import SwiftUI

// MARK: - Device Chrome Wrapper

/// Wraps a view with a device-appropriate status bar overlay.
struct DeviceChrome<Content: View>: View {
    let device: CaptureDevice
    let content: Content

    var body: some View {
        content
            .overlay(alignment: .top) {
                StatusBarView(style: device.statusBarStyle)
                    .ignoresSafeArea()
            }
    }
}

// MARK: - Status Bar Styles

enum StatusBarStyle {
    case modern   // iPhone 14 Pro+, 15, 16 — tall safe area, no pill
    case classic  // iPhone SE — no notch, thin status bar
}

extension CaptureDevice {
    var statusBarStyle: StatusBarStyle {
        switch self {
        case .iphoneSE: return .classic
        case .iphone15Pro, .iphone16ProMax: return .modern
        }
    }
}

// MARK: - Status Bar View

struct StatusBarView: View {
    let style: StatusBarStyle

    var body: some View {
        switch style {
        case .modern:
            dynamicIslandStatusBar
        case .classic:
            classicStatusBar
        }
    }

    // MARK: - Dynamic Island Layout
    // The safe area top inset is 59pt. No pill is rendered — just the status
    // bar items (time left, icons right) at the correct vertical position.

    private var dynamicIslandStatusBar: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.leading, 20)

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "cellularbars")
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "wifi")
                    .font(.system(size: 14, weight: .medium))
                BatteryIcon()
            }
            .foregroundColor(.white)
            .padding(.trailing, 20)
        }
        .frame(height: 59)
        .padding(.top, 14)
    }

    // MARK: - Classic Layout (iPhone SE)

    private var classicStatusBar: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.leading, 6)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "cellularbars")
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "wifi")
                    .font(.system(size: 12, weight: .medium))
                BatteryIcon(size: 11)
            }
            .foregroundColor(.white)
            .padding(.trailing, 6)
        }
        .frame(height: 20)
    }
}

// MARK: - Battery Icon

struct BatteryIcon: View {
    var size: CGFloat = 13

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white, lineWidth: 1)
                .frame(width: size * 1.8, height: size * 0.85)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white)
                .frame(width: size * 1.5, height: size * 0.55)
                .padding(.leading, 2)
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.white)
                .frame(width: 1.5, height: size * 0.35)
                .offset(x: size * 1.8 - 0.5)
        }
    }
}

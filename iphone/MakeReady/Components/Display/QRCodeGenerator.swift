//
//  QRCodeGenerator.swift
//  MakeReady
//
//  DEPRECATED: This file is no longer used.
//  All QR code generation now happens via the server API (see AuthManager.generateQRCode)
//
//  Original implementation used dagronf/QRCode library for local generation.
//  Keeping this file for reference but it's not compiled.
//

import UIKit
// import QRCode  // Commented out - no longer needed

/*
 // DEPRECATED - Use AuthManager.generateQRCode() instead

struct QRCodeGenerator {

    // MARK: - Invite QR Codes

    /// Generate a branded QR code for a MakeReady invite
    static func generateInviteQR(
        inviteCode: String,
        size: CGSize = CGSize(width: 400, height: 400),
        includeLogo: Bool = false
    ) throws -> UIImage {
        let url = "\(Configuration.clientBaseURL)/join/group/\(inviteCode)"
        return try generateQR(
            text: url,
            size: size,
            style: .branded,
            includeLogo: includeLogo
        )
    }

    // MARK: - Generic QR Generation

    /// Generate a QR code with custom styling
    static func generateQR(
        text: String,
        size: CGSize = CGSize(width: 400, height: 400),
        style: QRStyle = .branded,
        includeLogo: Bool = false
    ) throws -> UIImage {
        let doc = try QRCode.Document(utf8String: text)

        // Apply style
        switch style {
        case .branded:
            applyBrandedStyle(to: doc)
        case .basic:
            applyBasicStyle(to: doc)
        case .custom(let foreground, let background):
            applyCustomStyle(to: doc, foreground: foreground, background: background)
        }

        // Add logo if requested
        if includeLogo, let logoImage = UIImage(named: "AppIcon")?.cgImage {
            doc.logoTemplate = QRCode.LogoTemplate(
                image: logoImage,
                path: CGPath(
                    ellipseIn: CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.3),
                    transform: nil
                )
            )
        }

        return try doc.uiImage(size)
    }

    // MARK: - Private Style Methods

    private static func applyBrandedStyle(to doc: QRCode.Document) {
        // MakeReady brand purple (#6c47ff)
        let brandPurple = CGColor(red: 0.42, green: 0.28, blue: 1.0, alpha: 1.0)

        doc.design.style.onPixels = QRCode.FillStyle.Solid(brandPurple)
        doc.design.style.background = QRCode.FillStyle.Solid(.clear)
        doc.design.shape.eye = QRCode.EyeShape.RoundedRect()
        doc.design.shape.onPixels = QRCode.PixelShape.RoundedRect(cornerRadiusFraction: 0.3)

        // Error correction level M (default, balances capacity and error tolerance)
        doc.errorCorrection = .medium
    }

    private static func applyBasicStyle(to doc: QRCode.Document) {
        doc.design.style.onPixels = QRCode.FillStyle.Solid(.black)
        doc.design.style.background = QRCode.FillStyle.Solid(.clear)
        doc.errorCorrection = .medium
    }

    private static func applyCustomStyle(
        to doc: QRCode.Document,
        foreground: UIColor,
        background: UIColor
    ) {
        doc.design.style.onPixels = QRCode.FillStyle.Solid(foreground.cgColor)
        doc.design.style.background = QRCode.FillStyle.Solid(background.cgColor)
        doc.design.shape.eye = QRCode.EyeShape.RoundedRect()
        doc.design.shape.onPixels = QRCode.PixelShape.RoundedRect(cornerRadiusFraction: 0.3)
        doc.errorCorrection = .medium
    }
}

// MARK: - QR Style Options

enum QRStyle {
    case branded                                   // MakeReady purple branding
    case basic                                     // Black on transparent
    case custom(foreground: UIColor, background: UIColor)  // Custom colors
}

*/

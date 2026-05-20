# QR Code Generation Guide

This sub-agent provides comprehensive guidance on QR code generation in the MakeReady iPhone app.

## Overview

MakeReady uses **server-side QR code generation** with optional logo embedding. QR codes are generated fresh on every request (no caching) and link to invite URLs.

## Architecture

### Server-Side Generation
- **Endpoint**: `POST /api/qrcode/generate`
- **Location**: `/server/src/routes/qrcode.ts`
- **Libraries**: `qrcode` (generation) + `sharp` (image processing)
- **Features**: Logo embedding, color customization, variable sizing

### Client-Side Component
- **Component**: `InviteQRCodeView`
- **Location**: `/MakeReady/InviteQRCodeView.swift`
- **Type**: Reusable SwiftUI component with async loading

## Server API Endpoint

### POST /api/qrcode/generate

**Authentication**: Required (session cookie)

**Request Body**:
```json
{
  "data": "ABC123XYZ",            // Required: The invite code/data to encode
  "color": "#6c47ff",             // Optional: QR pixel color (default: brand purple)
  "backgroundColor": "#ffffff",   // Optional: Background color (default: white)
  "size": 600,                    // Optional: Size in pixels (default: 300, max: 2000)
  "errorCorrectionLevel": "M",    // Optional: L|M|Q|H (default: H)
  "includeLogo": true             // Optional: Embed logo in center (default: true)
}
```

**Response**:
```json
{
  "success": true,
  "qrCode": "data:image/png;base64,...",  // Base64 PNG data URL
  "url": "https://makeready.org/join/ABC123XYZ"  // Full invite URL
}
```

**Caching Headers** (prevents caching):
```
Cache-Control: no-cache, no-store, must-revalidate
Pragma: no-cache
Expires: 0
```

## iPhone Component Usage

### Basic Usage

```swift
import SwiftUI

struct MyView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        InviteQRCodeView(
            inviteCode: "ABC123XYZ",
            size: 320,
            includeLogo: true  // Optional: defaults to true
        )
    }
}
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `data` | String | Required | The invite code/data to encode |
| `size` | CGFloat | 300 | Display size in points |
| `includeLogo` | Bool | **true** | Whether to embed logo in center |

### Default Behavior

**As of the latest update:**
- Logo embedding is **ON by default** (`includeLogo: Bool = true`)
- QR codes will automatically include the MakeReady logo unless explicitly disabled
- Consistent across all uses (ShareInviteSheet, ComponentsPage, etc.)

### States

The component has three states:
1. **Generating**: Shows ProgressView while fetching from server
2. **Success**: Displays the QR code image
3. **Error**: Shows error icon and message

## Logo Embedding

### Logo File Location
```
/server/assets/makeready-logo-qr.png
```

### Logo Specifications
- **Format**: PNG with transparency
- **Recommended Size**: Square (e.g., 512x512)
- **Placement**: Center of QR code
- **Size**: ~20% of QR code size
- **Background**: White padding added automatically

### If Logo Missing
Server gracefully falls back to QR code without logo and logs:
```
[QR] Logo file not found, generating without logo
```

## Caching Prevention

### Client-Side (AuthManager.swift)
```swift
request.cachePolicy = .reloadIgnoringLocalCacheData  // Never cache QR codes
```

### Server-Side (qrcode.ts)
```typescript
res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
res.set('Pragma', 'no-cache');
res.set('Expires', '0');
```

### Why No Caching?
- QR codes should always reflect the latest invite data
- Each invite has a unique code
- Ensures users get fresh, valid QR codes

## Complete Integration Example

### 1. Create Invite API Call

```swift
// In your view or view model
Task {
    do {
        // Create invite via API
        let invite = try await authManager.createInvite()

        // Use the invite code for QR generation
        self.currentInviteCode = invite.code
        self.showQRSheet = true
    } catch {
        print("Error creating invite: \(error)")
    }
}
```

### 2. Display QR Code in Sheet

```swift
.sheet(isPresented: $showQRSheet) {
    if let inviteCode = currentInviteCode {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconLink(
                    leftIcon: "xmark",
                    rightLink: "Done",
                    onLeftIconTap: { dismiss() },
                    onRightLinkTap: { dismiss() }
                )

                VStack(spacing: 0) {
                    Spacer()

                    // QR Code Component
                    InviteQRCodeView(
                        inviteCode: inviteCode,
                        size: 320,
                        includeLogo: true
                    )

                    Spacer()

                    // Action buttons here
                }
            }
        }
    }
}
```

### 3. Generate High-Res QR for Sharing

```swift
@State private var qrCodeImage: UIImage?

// Generate high-resolution QR for sharing
private func generateQRImage() {
    Task {
        do {
            let image = try await authManager.generateQRCode(
                data: inviteCode,
                color: "#6c47ff",
                backgroundColor: "#ffffff",
                size: 800,  // High-res for sharing
                errorCorrectionLevel: "M",
                includeLogo: true
            )
            await MainActor.run {
                self.qrCodeImage = image
            }
        } catch {
            print("Error generating QR code: \(error)")
        }
    }
}

// Use in ShareLink
if let image = qrCodeImage {
    ShareLink(
        item: Image(uiImage: image),
        preview: SharePreview(
            "MakeReady Team Invite",
            image: Image(uiImage: image)
        )
    ) {
        Text("Share QR Code")
    }
}
```

## Common Issues & Solutions

### Issue: QR Code Not Showing Logo

**Symptoms**: QR code displays but no logo in center

**Causes**:
1. `includeLogo` set to `false`
2. Logo file missing on server
3. Server logo path incorrect

**Solutions**:
1. Check `InviteQRCodeView` parameters - ensure `includeLogo: true` or use default
2. Verify logo exists: `/server/assets/makeready-logo-qr.png`
3. Check server logs for: `[QR] Logo file not found`

### Issue: QR Code Appears Cached

**Symptoms**: Same QR code shown for different invite codes

**Causes**:
1. Missing cache policy on request
2. Server not sending no-cache headers

**Solutions**:
1. Verify `request.cachePolicy = .reloadIgnoringLocalCacheData` in AuthManager
2. Check server response headers include `Cache-Control: no-cache`
3. Restart server to apply header changes

### Issue: QR Code Generation Fails

**Symptoms**: Error state shown, no QR code

**Causes**:
1. Server not running
2. Not authenticated
3. Invalid invite code

**Solutions**:
1. Check server running on port 3001
2. Verify user is logged in (AuthManager.isAuthenticated)
3. Ensure invite code is valid and not empty

### Issue: QR Code Quality Poor

**Symptoms**: Blurry or pixelated QR code

**Causes**:
1. Size too small for retina displays
2. Error correction level too low

**Solutions**:
1. Use `size: Int(displaySize * 2)` for retina
2. Use error correction level "M" or "H" (higher = better quality)

## Best Practices

1. **Always use server-side generation** - Don't generate QR codes locally
2. **Default logo to true** - Maintain brand consistency
3. **2x size for retina** - Multiply display size by 2 for crisp rendering
4. **Error handling** - Always catch and handle generation errors
5. **Fresh generation** - Rely on cache prevention, don't store QR images
6. **Loading states** - Show ProgressView while generating
7. **High-res for sharing** - Use larger size (800px+) for ShareLink

## File Locations

### iPhone App
- Component: `/MakeReady/InviteQRCodeView.swift`
- API client: `/MakeReady/AuthManager.swift` (generateQRCode method)
- Example usage: `/MakeReady/ShareInviteSheet.swift`

### Server
- Route: `/server/src/routes/qrcode.ts`
- Logo: `/server/assets/makeready-logo-qr.png`
- Endpoint: `POST /api/qrcode/generate`

## Testing

### Manual Testing
1. Run server: `cd server && npm start`
2. Build iPhone app: `/rebuild-iphone`
3. Login to app
4. Tap Plus → Invite member → QR Code
5. Verify logo appears in center
6. Test Components tab → QR section
7. Verify both show logo consistently

### Test Different Configurations
```swift
// No logo
InviteQRCodeView(inviteCode: "TEST123", size: 200, includeLogo: false)

// Custom size
InviteQRCodeView(inviteCode: "TEST123", size: 400)

// Default (with logo)
InviteQRCodeView(inviteCode: "TEST123", size: 300)
```

## API Reference

### AuthManager.generateQRCode()

```swift
func generateQRCode(
    data: String,
    color: String = "#6c47ff",
    backgroundColor: String = "#ffffff",
    size: Int = 600,
    errorCorrectionLevel: String = "M",
    includeLogo: Bool = true
) async throws -> UIImage
```

**Parameters**:
- `data`: The invite code or data to encode in the QR code
- `color`: QR pixel color in hex format (default: brand purple)
- `backgroundColor`: Background color in hex format (default: white)
- `size`: Size in pixels (default: 600, max: 2000)
- `errorCorrectionLevel`: Error correction level L|M|Q|H (default: M)
- `includeLogo`: Whether to embed logo in center (default: true)

**Returns**: UIImage of the QR code
**Throws**: URLError, DecodingError, or custom errors

## Related Components

- `ShareInviteSheet.swift` - Modal for sharing QR codes
- `ComponentsPage.swift` - Demo page showing QR component
- `AuthManager.swift` - API client for QR generation
- `PageTitle.swift` - Title bar component for QR sheet

## Version History

- **v1.0** - Initial QR code generation with server API
- **v1.1** - Added logo embedding support
- **v1.2** - Implemented cache prevention (client + server)
- **v1.3** - Changed default `includeLogo` to `true` for consistency

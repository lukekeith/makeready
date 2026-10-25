//
//  InviteQrScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen invite-qr in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/groups/{id}/invite ·
//  GET /api/lesson-schedules/{id}/invite
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Invite QR — a multipurpose pushed page presenting one invite: its code (copyable), the
/// context's enter-a-code URL, the QR for the invite URL, and Share / Copy invite link (§2).
/// The context (group or enrolled lesson, §3 table) varies only the content; the layout does
/// not. Composed only of §4's C-040, C-048 ×2, C-110 and C-111. Standalone: the screen is not
/// minted from a collection (`identifiedFrom` is null), so no D7 template applies.
struct InviteQrScreen: View {

    /// The element a §3 `Copied` overlay sits over.
    enum CopiedTarget: String {
        case code
        case link
    }

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// The invite's code, shown verbatim on C-110 (e.g. `K7P4QX`).
        var code: String
        /// The context's enter-a-code URL in the hint line (§3 table: `app.makeready.org/join/group`).
        var hintURL: String
        /// The invite's `qrCode` as §5 returns it — a `data:image/png;base64,…` URL. `nil` is the
        /// blank plate (§3 `Loading`, `QR failed`, `Invite failed`; OQ-006).
        var qrCode: String?
        /// §3 `Copied`: `code` or `link` shows the overlay over that element; empty shows none.
        var copiedTarget: String
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    // The caller writes the pasteboard and fires the light haptic (§3 Copied).
    var onBack: () -> Void = {}             // C-040 back → pop to the pusher
    var onCopyCode: () -> Void = {}         // C-110 copy glyph → the bare code to the pasteboard
    var onShareInvite: () -> Void = {}      // Share invite → the iOS share sheet, invite URL only
    var onCopyLink: () -> Void = {}         // Copy invite link → the full invite URL to the pasteboard

    /// §5: "The QR image is media, decoded from `qrCode` and handed to C-111 as `image`."
    private let qrImage: Image?

    // §3 UI-only rule: "after either copy action … the 'Copied' overlay over the tapped element
    // fades in 150 ms, holds 1.2 s, fades out 200 ms. A second copy during the hold restarts the
    // hold." Seeded from `State`; `holdTick` counts taps so a seeded overlay is never timed out.
    @SwiftUI.State private var copied: CopiedTarget?
    @SwiftUI.State private var holdTick = 0

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onCopyCode: @escaping () -> Void = {},
        onShareInvite: @escaping () -> Void = {},
        onCopyLink: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onBack = onBack
        self.onCopyCode = onCopyCode
        self.onShareInvite = onShareInvite
        self.onCopyLink = onCopyLink
        self.qrImage = Self.decode(state.qrCode)
        _copied = SwiftUI.State(initialValue: CopiedTarget(rawValue: state.copiedTarget))
    }

    // MARK: - §2 constants

    private static let title = "Invite"
    private static let hintLead = "Use this code on "
    private static let shareLabel = "Share invite"
    private static let copyLinkLabel = "Copy invite link"
    private static let copiedLabel = "Copied"

    // FLAGGED LITERAL — invite-qr §2 FL-1: 16 (code-group and action-group stack gaps; same value
    // as `space-card-padding` / `space-page-margin`, different role).
    private static let stackGap: CGFloat = 16
    // GAP — invite-qr §2 3b: "C-111 QRCodeImage — 280×280 … the screen sets the width
    // (`.frame(width: 280)`)"; no size token.
    private static let qrWidth: CGFloat = 280
    private static var hintLine: CGFloat { Token.TypeStyle.body.lineHeight ?? Token.TypeStyle.body.size }
    // GAP — invite-qr §3 state 5: the Copied overlay "fades in 150 ms"; no motion token.
    private static let overlayIn = Animation.easeInOut(duration: 0.15)
    // GAP — invite-qr §3 state 5: "fades out 200 ms"; no motion token.
    private static let overlayOut = Animation.easeInOut(duration: 0.2)
    // GAP — invite-qr §3 state 5: "holds 1.2 s"; no duration token.
    private static let overlayHold: Duration = .milliseconds(1200)

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root. The status bar (§1 deviation 1) is the harness's.
        VStack(spacing: 0) {
            // §2 item 2: C-040 `twoIcons`, title "Invite", `showIcons: false`, leading back.
            PageHeader(
                style: .twoIcons,
                title: Self.title,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            // §2 item 3: content column — padding `space-page-margin`, children centred, gap
            // `space-section-gap` between the three groups.
            VStack(spacing: Token.Space.sectionGap) {
                codeGroup
                // §2 3b: C-111, 280 wide and centred; the component keeps itself square.
                QRCodeImage(image: qrImage)
                    .frame(width: Self.qrWidth)
                    .ui2Element("C-111 QRCodeImage")
                actionGroup
            }
            .padding(Token.Space.pageMargin)
        }
        // §2 item 4: empty background below the buttons; the column stays top-anchored.
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)
        .task(id: holdTick) {
            guard holdTick > 0 else { return }
            try? await Task.sleep(for: Self.overlayHold)
            guard !Task.isCancelled else { return }
            copied = nil
        }
    }

    // MARK: - §2 3a — code group

    private var codeGroup: some View {
        VStack(spacing: Self.stackGap) {
            CopyableCodeCard(code: state.code, copied: copied == .code, onCopy: copyCode)
                .ui2Element("C-110 CopyableCodeCard")
            hintLine
        }
    }

    /// §2 3a hint line: centred, one line, `type-body`; the lead in `color-text-secondary`, the
    /// context's enter-a-code URL in `color-accent`. Display-only (§3: not interactive).
    private var hintLine: some View {
        (Text(Self.hintLead).foregroundColor(Token.textSecondary)
            + Text(state.hintURL).foregroundColor(Token.accent))
            .designTextStyle(Token.TypeStyle.body)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            // `type-body` is Regular 14 / 14: the line box is pinned to the designed 14pt rather
            // than the font's own taller natural line (the C-110 precedent).
            .frame(height: Self.hintLine)
            .frame(maxWidth: .infinity)
    }

    // MARK: - §2 3c — action group

    private var actionGroup: some View {
        VStack(spacing: Self.stackGap) {
            PageActionButton(
                label: Self.shareLabel,
                role: .accent,
                size: .md,
                glyph: .sendFilled,                 // §1 deviation 6: the library's `send-filled`
                glyphPosition: .trailing,
                layout: .spread,
                onTap: onShareInvite
            )
            .ui2Element("C-048 PageActionButton")

            PageActionButton(
                label: Self.copyLinkLabel,
                role: .secondary,
                size: .md,
                glyph: .copy,
                glyphPosition: .trailing,
                layout: .spread,
                onTap: copyLink
            )
            .overlay { linkCopiedOverlay }
            .ui2Element("C-048 PageActionButton 2")
        }
    }

    /// §2 Copied overlay over the Copy invite link button (OQ-003 / OQ-007): the button's bounds
    /// with `radius-card`, fill `color-accent-50`, "Copied" centred in `type-label-emphasis`,
    /// `color-text-primary`. (Over C-110 the card draws its own, through `copied`.)
    private var linkCopiedOverlay: some View {
        let showing = copied == .link
        return ZStack {
            RoundedRectangle(cornerRadius: Token.Radius.card)
                .fill(Token.accent50)
            Text(Self.copiedLabel)
                .designTextStyle(Token.TypeStyle.labelEmphasis)
                .foregroundColor(Token.textPrimary)
                .lineLimit(1)
        }
        .opacity(showing ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(!showing)
        .animation(showing ? Self.overlayIn : Self.overlayOut, value: showing)
    }

    // MARK: - §3 interactions

    private func copyCode() {
        onCopyCode()
        showCopied(.code)
    }

    private func copyLink() {
        onCopyLink()
        showCopied(.link)
    }

    /// §3 state 5: show the overlay over `target`; a second copy during the hold restarts it
    /// (a new `holdTick` cancels the running hold).
    private func showCopied(_ target: CopiedTarget) {
        copied = target
        holdTick += 1
    }

    /// §5 `qrCode`: a base64 PNG data URL. Anything else — or `nil` — is the blank plate.
    private static func decode(_ dataURL: String?) -> Image? {
        guard let dataURL, dataURL.hasPrefix("data:"),
              let comma = dataURL.firstIndex(of: ","),
              let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...])),
              let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
}

// MARK: - Sample data (the previews' props, single-sourced)

extension InviteQrScreen.State {
    /// §3 `Populated` — the frame: code `K7P4QX` (§1 deviation 4), the group context's hint URL
    /// (§3 table, deviation 3) and a sample QR (encodes
    /// `https://app.makeready.org/join/group/K7P4QX`).
    static let populated = Self(code: "K7P4QX", hintURL: "app.makeready.org/join/group",
                                qrCode: sampleQRCode, copiedTarget: "")
    /// §3 `Loading` — the code and buttons at once; the plate blank until the image arrives.
    static let loading = Self(code: "K7P4QX", hintURL: "app.makeready.org/join/group",
                              qrCode: nil, copiedTarget: "")
    /// §3 `QR failed` — the plate stays blank; the code and buttons still work.
    static let qrFailed = Self(code: "K7P4QX", hintURL: "app.makeready.org/join/group",
                               qrCode: nil, copiedTarget: "")
    /// §3 `Invite failed` — the shell's error surface is the shell's; on this page the cached
    /// code renders (D39), the plate stays blank and back still works.
    static let inviteFailed = Self(code: "K7P4QX", hintURL: "app.makeready.org/join/group",
                                   qrCode: nil, copiedTarget: "")
    /// §3 `Copied` — the overlay over Copy invite link (the screen-owned overlay; C-110 draws
    /// its own and is captured in its own build).
    static let copied = Self(code: "K7P4QX", hintURL: "app.makeready.org/join/group",
                             qrCode: sampleQRCode, copiedTarget: "link")

    /// A sample of §5's `qrCode`: the server's own `qrcode` library encoding
    /// `https://app.makeready.org/join/group/K7P4QX` (black modules on white, no logo), at one
    /// pixel per module (C-111 samples nearest-neighbour, so it renders sharp at 280pt).
    static let sampleQRCode = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACEAAAAhCAYAAABX5MJvAAAAAklEQVR4AewaftIAAAJLSURBVM3BQQrbCBAAwW6h/3+51wMeEMLyOqekyl74yw7+ASdvKk8qVK4q7lSuKlSeVIyTi4o7lbuKpVIxKlQqVFbFnco6uFFRUbmqGBVLpWKofKOionJ38COVoTJUlspQqVCp+NXBjypGxTcqQ+VXJzcV36hUjAqViqFSoXJX8eTkQuWJSoXKJyoVKhUqS+Wbk7eKP6VSsVQqrir+z8GbylBRGSoqKhUqQ2VUrIqhcqWyVIaKyjp4q1gVq2KojIqKO5WKoTJUhopKxai4OviiQmVUDJWlonJX8URFpWId3FSoqIyKTyqWSsVSeVJRobLshQ9UVoVKxZVKxVIZFZ+ojIore+FNZVWoVKhUDJUnFUOlYqiMiqGyKsbBm0rFUhkqVxWroqJiqKgMlVXxjb3wpjIqvlGpUKn4hUrFUKlYBzcVQ2WoqAwVlYpRoTJUhspQUblS+eTgA5UKlYqKVbFUKlQqVCpWxVCpGCp3B28qFVcVKioqS+VOZagsFZUKlYpRcXXwVjFUKlRGRUXFUKlQqbirGBVLpeLJyYVKhUrFULmquKtQGSqfqDyxF36gUqFSobIqVFaFSsVSuasYJ28qTypWhUqFylWFispSqVgVKhXr5KLiTuUTlVGhUrEqVEbFXYVKxTi5UVkVq0JlVKhUjIqhUrFUripUKirWwY9UriqWyqhYFaOiYqhUDJV18AcqPqlQWSqjYqhUVKjcndxUfFKhUrFURsWdSsVSGRUqFevkQuWJylAZFRVDpWKoLJWKUfHEXvjLDv4B/wGbkO961zEeuwAAAABJRU5ErkJggg=="
}

#Preview("Populated") {
    InviteQrScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Loading") {
    InviteQrScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("QR failed") {
    InviteQrScreen(state: .qrFailed)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Invite failed") {
    InviteQrScreen(state: .inviteFailed)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Copied") {
    InviteQrScreen(state: .copied)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

//
//  LoginScreen.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from screen login in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /auth/google?platform=ios ·
//  POST /auth/exchange · GET /auth/me · GET /auth/leader-access · POST /auth/logout
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Login — "show the logo and provide a way for the group leader to login with their google
/// credentials" (owner description). The unauthenticated root of the 2.0 leader app (D1): a
/// full-bleed `color-layout-background` page with ONE vertical stack centred in the page-margin
/// inner box — the `makeready-logo` glyph, the welcome line, and C-104 AuthProviderButton (§2).
/// Composed only of §4's C-104; the logo is a library glyph and the welcome line is screen text
/// (§4: neither is a component).
struct LoginScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §3 `authenticating` — drives C-104 `loading` (the C-076 spinner replaces the mark,
        /// taps swallowed; ruled OQ-login-002). `false` is §3 `idle`.
        var authenticating: Bool
        /// §3 `error` — the message shown in place of the welcome line; "" = no error (§3 `idle`
        /// / `authenticating`). Owner ruling OQ-login-003 (2026-10-08 20:56 UTC): the welcome
        /// line BECOMES the error message, kept short ("Authentication failed"); the
        /// leader-access copy is OQ-login-005's "This account doesn't have leader access."
        var errorMessage: String
    }

    let state: State
    // §3 interactions that leave the screen — one on<Verb> closure with R-03's no-op default.
    var onSignIn: () -> Void = {}   // C-104 `onTap` → open the Google sign-in session (§3, §5)

    init(state: State, onSignIn: @escaping () -> Void = {}) {
        self.state = state
        self.onSignIn = onSignIn
    }

    // MARK: - §2 constants (values that no §3 state changes)

    /// §2: the welcome line's copy, verbatim; one line, never wraps.
    private static let welcome = "Welcome to MakeReady"
    /// GAP — login §2: "glyph `makeready-logo` drawn at 96×84" (`4586:9213` bounds); no sizing
    /// token. The library glyph sits inset in a 24-point box, so its art renders a little
    /// smaller than the frame's trimmed vector (reported as a glyph-library gap).
    private static let logoWidth: CGFloat = 96
    private static let logoHeight: CGFloat = 84
    /// GAP — login §2: "centred both horizontally and vertically in the inner box" needs the
    /// content region's height — the device canvas (956) minus its top safe-area inset (59) on
    /// iphone-16-pro-max — and no device-size token exists. The region still fills whatever
    /// height the app proposes (`maxHeight: .infinity`); this is only its floor.
    private static let contentRegionHeight: CGFloat = 897

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root. §2: the content region starts at the device's top
        // safe-area inset (the harness draws the status bar); `space-page-margin` on all four
        // sides; everything inside is ONE stack centred both ways in the inner box.
        stack
            .frame(maxWidth: .infinity, maxHeight: .infinity)      // §2: centred in the inner box
            .padding(Token.Space.pageMargin)                       // §2: `space-page-margin` ×4
            .frame(maxWidth: .infinity, minHeight: Self.contentRegionHeight, maxHeight: .infinity)
            .background(Token.layoutBackground)                    // §2: `color-layout-background`
    }

    /// §2: logo, welcome line, C-104 — gap `space-section-gap` between items, hugging its
    /// content width.
    private var stack: some View {
        VStack(alignment: .center, spacing: Token.Space.sectionGap) {
            logo
            welcomeLine
            providerButton
        }
    }

    /// §2 Logo — glyph `makeready-logo` at 96×84, fill `color-text-primary`. Decorative: no hit
    /// target, hidden from accessibility (the screen's title is the label).
    private var logo: some View {
        Image(GlyphName.makereadyLogo.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFill()
            .frame(width: Self.logoWidth, height: Self.logoHeight)
            .clipped()
            .foregroundStyle(Token.textPrimary)
            .accessibilityHidden(true)
    }

    /// §2 Welcome line — "Welcome to MakeReady", `type-body`, `color-text-secondary` (the token;
    /// ruled OQ-login-001), centred, one line. §3 `error` (ruled OQ-login-003): the same line
    /// carries the error message instead, in `color-negative` (§3's error-text colour).
    private var welcomeLine: some View {
        let showingError = !state.errorMessage.isEmpty
        return Text(showingError ? state.errorMessage : Self.welcome)
            .designTextStyle(Token.TypeStyle.body)
            .foregroundStyle(showingError ? Token.negative : Token.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(1)
    }

    /// §4: C-104 AuthProviderButton — `provider: .google`, `loading` = §3 `authenticating`,
    /// `onTap` = the sign-in exit. Intrinsically 96×96; the screen does not size it.
    private var providerButton: some View {
        AuthProviderButton(provider: .google, loading: state.authenticating, onTap: onSignIn)
            .ui2Element("C-104 AuthProviderButton")
    }
}

// MARK: - §3 sample states

extension LoginScreen.State {
    /// §3 `idle` (frame `default`): the §2 layout, C-104 enabled.
    static let idle = Self(authenticating: false, errorMessage: "")
    /// §3 `authenticating`: C-104 `loading` — the spinner replaces the Google mark.
    static let authenticating = Self(authenticating: true, errorMessage: "")
    /// §3 `error`: the welcome line replaced by the short failure copy (OQ-login-003).
    static let error = Self(authenticating: false, errorMessage: "Authentication failed")
}

#Preview("idle") {
    LoginScreen(state: .init(authenticating: false, errorMessage: ""))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("authenticating") {
    LoginScreen(state: .init(authenticating: true, errorMessage: ""))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("error") {
    LoginScreen(state: .init(authenticating: false, errorMessage: "Authentication failed"))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

//
//  BibleVersesScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen bible-verses in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/bible/:code/:book/:chapter (the verse count, D18)
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Bible verses — the third page of the Bible passage picker (bible-verse-picker D1/D2):
/// C-040 back + "<Book> <chapter>", then a 6-column grid of C-052 day cells, verses 1…N, N from
/// this chapter's fetch (D18). A verse this lesson already uses draws DayChip's `isUsed` outline
/// (D5). Every exit is an `on<Verb>` closure (R-03).
struct BibleVersesScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. The verse cells are
    /// 1…`verseCount` in order (§2), so the count and the used set are the whole grid.
    struct State {
        /// C-040 `title` — "<Book> <chapter>" ("John 3").
        var title: String
        /// This chapter's verse count from its fetch (D18); 0 until it arrives.
        var verseCount: Int
        /// The verses this lesson uses (D16) — C-052 `isUsed`.
        var usedVerses: [Int]
        /// §3 loading — the brief's `isLoading`, spelled bare by R-34.
        var loading: Bool
    }

    let state: State
    // §3 taps that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                        // C-040 back / edge-swipe → bible-chapters
    var onSelect: (Int) -> Void = { _ in }             // verse cell n → bible-reader at verse n

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSelect: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onSelect = onSelect
    }

    /// §2 Verse grid: 6 equal flexible columns.
    private static let columns = 6

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // §2 / D22: no ScrollView at the root — the host container scrolls; the capture canvas
        // lays the page out at its full length. The status bar is the harness's.
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {   // §2 2: section-gap below the header
            pageHeader
            bodyRegion
                .padding(.horizontal, Token.Space.pageMargin)            // §2 2: page-margin inset
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)                              // `color-layout-background`
    }

    // MARK: §2 1. Page top

    /// C-040 "Two icons · showTitle · no showIcons": back · "<Book> <chapter>", `rightButtons: []`.
    private var pageHeader: some View {
        PageHeader(
            style: .twoIcons,
            title: state.title,
            showTitle: true,
            showIcons: false,
            leadingGlyph: .back,
            rightButtons: [],
            onLeading: onBack
        )
        .ui2Element("C-040 PageHeader")
    }

    // MARK: §2 2. Body region

    /// Exactly one of: the spinner (loading), the verse grid (populated), nothing (failed).
    /// §3: empty cells with `loading == false` is failed — a chapter always has ≥ 1 verse.
    @ViewBuilder
    private var bodyRegion: some View {
        if state.loading {
            // §2 2 / OQ-bible-verses-003: C-076 at its defaults, centred in the body region.
            ActivitySpinner()
                .ui2Element("C-076 ActivitySpinner")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading verses")                    // §3 1
        } else if state.verseCount > 0 {
            verseGrid
        } else {
            // §3 failed: the body stays empty; the app's top banner carries Retry (D18, D24).
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// One C-052 `.label("n")` per verse, row-major; each chip fills its column, 48 tall (owner 2026-11-11: same rule as the bible-books grid — column count and gap set the width);
    /// `space-element-gap` between columns and rows (OQ-bible-verses-002). A short last row is
    /// left-aligned and keeps the column width.
    private var verseGrid: some View {
        let count = max(state.verseCount, 0)
        let rows = stride(from: 1, through: count, by: Self.columns).map { start in
            Array(start...min(start + Self.columns - 1, count))
        }
        return VStack(spacing: Token.Space.elementGap) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: Token.Space.elementGap) {
                    ForEach(row, id: \.self) { verse in
                        DayChip(
                            content: .label(String(verse)),
                            state: .default,
                            isEmpty: false,
                            fillToken: nil,
                            isUsed: state.usedVerses.contains(verse),
                            onTap: { onSelect(verse) }
                        )
                        .ui2Element(Self.partName("C-052 DayChip", ordinal: verse))
                    }
                    ForEach(row.count..<Self.columns, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
    }

    /// `"C-### <Name>"`, with `" N"` from the second instance on (D11).
    private static func partName(_ base: String, ordinal: Int) -> String {
        ordinal <= 1 ? base : "\(base) \(ordinal)"
    }
}

// MARK: - Sample states (the preview props, written as Swift)

extension BibleVersesScreen.State {
    /// §3 1 loading — John 3's verse count has not arrived yet.
    static let loadingSample = Self(
        title: "John 3",
        verseCount: 0,
        usedVerses: [],
        loading: true
    )

    /// §3 2 populated — John 3's 36 verses (the SPEC walk's "John 3:1–36"); 16–18 are used by the
    /// fixture lesson (John 3:16b-18, the D10 walk passage).
    static let populated = Self(
        title: "John 3",
        verseCount: 36,
        usedVerses: [16, 17, 18],
        loading: false
    )

    /// §3 3 failed — the fetch failed: no cells, not loading.
    static let failedSample = Self(
        title: "John 3",
        verseCount: 0,
        usedVerses: [],
        loading: false
    )
}

#Preview("loading") {
    BibleVersesScreen(state: .loadingSample)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("populated") {
    BibleVersesScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("failed") {
    BibleVersesScreen(state: .failedSample)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

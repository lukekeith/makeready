//
//  BibleChaptersScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen bible-chapters in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: none (bundled chapter counts, D24).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Bible chapters — the second page of the Bible passage picker (bible-verse-picker D1/D2):
/// C-040 back + the book name, then a 6-column grid of C-052 day cells, chapters 1…N. A chapter
/// this lesson already uses draws DayChip's `isUsed` outline (D5). Every exit is an `on<Verb>`
/// closure (R-03).
struct BibleChaptersScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. The chapter cells are
    /// 1…`chapterCount` in order (§2), so the count and the used set are the whole grid.
    struct State {
        /// C-040 `title` — the book name ("John").
        var title: String
        /// The bundled chapter count (D24); a one-chapter book is 1 (D1).
        var chapterCount: Int
        /// The chapters this lesson uses (D16) — C-052 `isUsed`.
        var usedChapters: [Int]
    }

    let state: State
    // §3 taps that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                        // C-040 back / edge-swipe → bible-books
    var onSelect: (Int) -> Void = { _ in }             // chapter cell → bible-verses

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSelect: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onSelect = onSelect
    }

    /// §2 Chapter grid: 6 equal flexible columns.
    private static let columns = 6

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // §2 / D53: C-040 is fixed; the chapter grid scrolls in the screen's own ScrollView,
        // filling the remaining height. The status bar is the harness's.
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {   // §2 2: section-gap below the header
            pageHeader
            ScrollView(.vertical) {
                chapterGrid
                    .padding(.horizontal, Token.Space.pageMargin)        // §2 2: page-margin inset
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)                              // `color-layout-background`
    }

    // MARK: §2 1. Nav

    /// C-040 "Two icons · showTitle · no showIcons": back · book name, `rightButtons: []`.
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

    // MARK: §2 2. Chapter grid

    /// One C-052 `.label("n")` per chapter, row-major; each chip fills its column, 48 tall (owner 2026-11-11: same rule as the bible-books grid — column count and gap set the width);
    /// `space-element-gap` between columns and rows (OQ-bible-chapters-001). A short last row
    /// keeps the column width.
    private var chapterGrid: some View {
        let count = max(state.chapterCount, 0)
        let rows = stride(from: 1, through: count, by: Self.columns).map { start in
            Array(start...min(start + Self.columns - 1, count))
        }
        return VStack(spacing: Token.Space.elementGap) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: Token.Space.elementGap) {
                    ForEach(row, id: \.self) { chapter in
                        DayChip(
                            content: .label(String(chapter)),
                            state: .default,
                            isEmpty: false,
                            fillToken: nil,
                            isUsed: state.usedChapters.contains(chapter),
                            onTap: { onSelect(chapter) }
                        )
                        .ui2Element(Self.partName("C-052 DayChip", ordinal: chapter))
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

extension BibleChaptersScreen.State {
    /// §3 1 populated — John's 21 bundled chapters; chapter 3 is used by the fixture lesson
    /// (John 3:16b-18, the D10 walk passage; bible-books marks John used).
    static let populated = Self(
        title: "John",
        chapterCount: 21,
        usedChapters: [3]
    )
}

#Preview("populated") {
    BibleChaptersScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

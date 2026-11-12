//
//  BibleReaderScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen bible-reader in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/bible/{translationCode}/{bookNumber}/{chapter} ·
//  GET /api/bible/translations · POST /api/search/smart (its result is passed in, never called here)
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Bible reader — the last step of the Bible passage picker (Books → Chapters → Verses → Reader):
/// a pushed full-screen page with C-040 PageHeader (back, "<Book> <chapter>", Select), one C-035
/// translation chip, and C-140 BibleVerseReader filling the rest (§2). Standalone: the screen is not
/// minted from a collection (`identifiedFrom` is null), so no D7 template applies.
///
/// Controlled (R-01): the selection is a `State` value and every change leaves through
/// `onSelectionChange`; the screen holds no copy of it.
struct BibleReaderScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// C-040 `title` — "<Book> <chapter>", e.g. "John 3".
        var title: String
        /// C-035 `label` — the current translation's full code as served (D7), never truncated.
        var translationCode: String
        /// C-035 `label` — the translation's name as the chip shows it; nil = `translationCode`.
        /// One line, tail-truncated.
        var translationLabel: String? = nil
        /// The C-036 single-select's options, parallel to `translationNames` (popularity order,
        /// D7). Not drawn on this screen — the chip presents them (§6, deviation 7).
        var translationCodes: [String]
        /// The C-036 options' names, parallel to `translationCodes`.
        var translationNames: [String]
        /// C-140 `chapterHeading`.
        var chapterHeading: String
        /// C-140 `verses`.
        var verses: [BibleVerseReader.Verse]
        /// C-140 `selection` — nil = none (§3 populated).
        var selection: BibleVerseReader.Selection?
        /// C-140 `usedRanges` — words this lesson's draft already uses (D16).
        var usedRanges: [BibleVerseReader.Selection]
        /// C-140 `copyright` (D20).
        var copyright: String
        /// C-140 `scrollToVerse` — the entry verse (§3 Entry); nil = top.
        var scrollToVerse: Int?
        /// C-140 `hasPreviousChapter` (deviation 6) — false at Genesis 1.
        var hasPreviousChapter: Bool
        /// C-140 `hasNextChapter` (deviation 6) — false at Revelation 22.
        var hasNextChapter: Bool
        /// §3 loading — C-076 in place of C-140 (the brief's `isLoading`, spelled bare by R-34).
        var loading: Bool
        /// §3 failed — the reader body is empty; the Retry banner is the app's (D24).
        var failed: Bool
        /// C-040 `trailingEnabled` — Select is tappable only while a selection exists (D2).
        var canSelect: Bool
    }

    let state: State
    var onBack: () -> Void = {}
    var onSelect: () -> Void = {}
    var onSelectionChange: (BibleVerseReader.Selection?) -> Void = { _ in }
    var onSwipeChapter: (Int) -> Void = { _ in }
    var onTranslation: (String) -> Void = { _ in }
    var onTopVerseChange: (Int) -> Void = { _ in }
    /// The C-035 chip's tap — the caller presents C-036 over `translations` and answers with
    /// `onTranslation(code)` (§3).
    var onTranslationMenu: () -> Void = {}

    var body: some View {
        // §2 top → bottom. The status bar and safe areas are the harness's, never drawn here.
        VStack(alignment: .leading, spacing: 0) {
            // §2.1 page top: `backAndLink`, back + title + "Select", enabled only while
            // `canSelect`. Fixed — does not scroll.
            PageHeader(
                style: .backAndLink,
                title: state.title,
                leadingGlyph: .back,
                rightButtons: [],
                trailingLabel: Self.selectLabel,
                trailingEnabled: state.canSelect,
                onLeading: onBack,
                onDone: onSelect
            )
            .ui2Element("C-040 PageHeader")

            // §2.2 translation row: one C-035 `type=Menu`, label = `translationLabel` (else the
            // code), never active. Leading-aligned, inset by `space-page-margin`. Fixed — does not scroll.
            FilterChip(type: .menu, active: false, label: state.translationLabel ?? state.translationCode,
                       onTap: onTranslationMenu)
                .ui2Element("C-035 FilterChip")
                .padding(.horizontal, Token.Space.pageMargin)

            // §2.3 reader body: fills the remaining height, inset by `space-page-margin`.
            readerBody
                .padding(.horizontal, Token.Space.pageMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)
    }

    @ViewBuilder
    private var readerBody: some View {
        if state.loading {
            // §2.3 / OQ-bible-reader-005: C-076 at its defaults, centred in the reader body.
            ActivitySpinner()
                .ui2Element("C-076 ActivitySpinner")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if state.failed {
            // §3 failed: the region is empty; the app's banner carries Retry (D24).
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // C-140 owns its vertical ScrollView — the ruled exception to `no-root-scroll`.
            BibleVerseReader(
                chapterHeading: state.chapterHeading,
                verses: state.verses,
                selection: state.selection,
                usedRanges: state.usedRanges,
                copyright: state.copyright,
                scrollToVerse: state.scrollToVerse,
                hasPreviousChapter: state.hasPreviousChapter,
                hasNextChapter: state.hasNextChapter,
                onSelectionChange: onSelectionChange,
                onTopVerseChange: onTopVerseChange,
                onPreviousChapter: { onSwipeChapter(-1) },
                onNextChapter: { onSwipeChapter(1) }
            )
            .ui2Element("C-140 BibleVerseReader")
        }
    }

    /// §2.1: the trailing link's copy (D2).
    private static let selectLabel = "Select"
}

// MARK: - Sample data (§3 states; the verses and copyright are C-140's own contract samples)

extension BibleReaderScreen.State {
    /// John 3:1–21, ENGKJV — C-140's sample chapter.
    static let sampleVerses: [BibleVerseReader.Verse] = [
        .init(number: 1, text: "There was a man of the Pharisees, named Nicodemus, a ruler of the Jews:"),
        .init(number: 2, text: "The same came to Jesus by night, and said unto him, Rabbi, we know that thou art a teacher come from God: for no man can do these miracles that thou doest, except God be with him."),
        .init(number: 3, text: "Jesus answered and said unto him, Verily, verily, I say unto thee, Except a man be born again, he cannot see the kingdom of God."),
        .init(number: 4, text: "Nicodemus saith unto him, How can a man be born when he is old? can he enter the second time into his mother's womb, and be born?"),
        .init(number: 5, text: "Jesus answered, Verily, verily, I say unto thee, Except a man be born of water and of the Spirit, he cannot enter into the kingdom of God."),
        .init(number: 6, text: "That which is born of the flesh is flesh; and that which is born of the Spirit is spirit."),
        .init(number: 7, text: "Marvel not that I said unto thee, Ye must be born again."),
        .init(number: 8, text: "The wind bloweth where it listeth, and thou hearest the sound thereof, but canst not tell whence it cometh, and whither it goeth: so is every one that is born of the Spirit."),
        .init(number: 9, text: "Nicodemus answered and said unto him, How can these things be?"),
        .init(number: 10, text: "Jesus answered and said unto him, Art thou a master of Israel, and knowest not these things?"),
        .init(number: 11, text: "Verily, verily, I say unto thee, We speak that we do know, and testify that we have seen; and ye receive not our witness."),
        .init(number: 12, text: "If I have told you earthly things, and ye believe not, how shall ye believe, if I tell you of heavenly things?"),
        .init(number: 13, text: "And no man hath ascended up to heaven, but he that came down from heaven, even the Son of man which is in heaven."),
        .init(number: 14, text: "And as Moses lifted up the serpent in the wilderness, even so must the Son of man be lifted up:"),
        .init(number: 15, text: "That whosoever believeth in him should not perish, but have eternal life."),
        .init(number: 16, text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."),
        .init(number: 17, text: "For God sent not his Son into the world to condemn the world; but that the world through him might be saved."),
        .init(number: 18, text: "He that believeth on him is not condemned: but he that believeth not is condemned already, because he hath not believed in the name of the only begotten Son of God."),
        .init(number: 19, text: "And this is the condemnation, that light is come into the world, and men loved darkness rather than light, because their deeds were evil."),
        .init(number: 20, text: "For every one that doeth evil hateth the light, neither cometh to the light, lest his deeds should be reproved."),
        .init(number: 21, text: "But he that doeth truth cometh to the light, that his deeds may be made manifest, that they are wrought in God."),
    ]

    static let sampleCopyright = "PUBLIC DOMAIN except in the United Kingdom, where a Crown Copyright applies to printing the KJV."

    /// §3 populated — no selection, Select dimmed.
    static let populated = BibleReaderScreen.State(
        title: "John 3",
        translationCode: "ENGKJV",
        translationCodes: [],
        translationNames: [],
        chapterHeading: "John 3",
        verses: sampleVerses,
        selection: nil,
        usedRanges: [],
        copyright: sampleCopyright,
        scrollToVerse: nil,
        hasPreviousChapter: true,
        hasNextChapter: true,
        loading: false,
        failed: false,
        canSelect: false
    )

    /// §3 loading — C-076 in the reader body; title and chip stay, Select dimmed.
    static var loadingSample: BibleReaderScreen.State {
        var s = populated
        s.verses = []
        s.chapterHeading = ""
        s.copyright = ""
        s.loading = true
        return s
    }

    /// §3 populated-with-selection — C-140's `selection-partial` range (16:4 … 18:42), Select enabled.
    static var populatedWithSelection: BibleReaderScreen.State {
        var s = populated
        s.selection = .init(startVerse: 16, startOffset: 4, endVerse: 18, endOffset: 42)
        s.scrollToVerse = 16
        s.canSelect = true
        return s
    }

    /// §3 failed — the reader body is empty.
    static var failedSample: BibleReaderScreen.State {
        var s = loadingSample
        s.loading = false
        s.failed = true
        return s
    }
}

#Preview("loading") {
    BibleReaderScreen(state: .loadingSample)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("populated") {
    BibleReaderScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("populated-with-selection") {
    BibleReaderScreen(state: .populatedWithSelection)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("failed") {
    BibleReaderScreen(state: .failedSample)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

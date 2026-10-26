# dashboard-chart-intros — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every chart on the UI 2.0 iPhone home dashboard plays a one-time intro animation the first time its section scrolls ≥ 50 % into view each Home visit, and morphs on data changes — with every capture, fixture and other screen left exactly as it renders today.

**Architecture:** One shared `ChartIntro?` value per chart (MakeReadyUI/ChartIntro.swift): `nil` = today's still render (D7); otherwise its `played` flag flips false → true once, and each chart keys implicit `.animation(_:value: intro?.played)` modifiers — with per-element delays — on that flip, so the start pose animates to a final pose identical to the `nil` render. No `asyncAfter`, no `Task.sleep`. `HomeDashboardScreen` owns a `ChartIntroLedger` (`@State`, D15) fed by `onScrollVisibilityChange(threshold: 0.5)` and by the shell's `chartIntroActive` environment value (`UI2ShellModel.homeActive`, D15 revised).

**Tech Stack:** iphone — SwiftUI (iOS 26), `MakeReadyUI` sources compiled into the `MakeReady` module, XCTest in `MakeReadyCaptureTests` (`@testable import MakeReady`).

**Spec:** docs/features/dashboard-chart-intros/SPEC.md

## Global Constraints


- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(dashboard-chart-intros): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.


## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | iphone | 1–2 | The intro vocabulary exists and is tested: `ChartIntro`, `ChartIntroMotion`, count-up, the played ledger and the shell's `homeActive` signal — nothing on screen changes yet | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 2 | iphone | 3–7 | The seven charts take an optional intro (default `nil`, still render unchanged) and the live Home dashboard turns them on | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: ChartIntro, ChartIntroMotion and the count-up
App: iphone
Phase: 1
Recipe: /transition-review — motion values and implicit animations; read `iphone/.claude/SWIFTUI_TRANSITIONS.md` first. SPEC D3, D7, D9, D10, D13, D14, D16.

**Files:**
- Create: `iphone/MakeReadyUI/ChartIntro.swift`
- Create: `iphone/MakeReadyUI/CountUp.swift`
- Create: `iphone/MakeReadyCaptureTests/ChartIntroTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (via the sync scripts and the xcodeproj snippet below — never by hand)

**Interfaces:**
- Produces:
  - `struct ChartIntro: Equatable { var played: Bool; var reduceMotion: Bool = false; var delay: Double = 0; func progress(fadeOnly: Bool) -> Double; func opacity(fadeOnly: Bool) -> Double; func animation(_ base: Animation, after extra: Double = 0) -> Animation?; var morph: Animation?; func delayed(by extra: Double) -> ChartIntro; static func scaled(_ length: CGFloat, by progress: Double) -> CGFloat }`
  - `enum ChartIntroMotion { static let rise, draw, countUp, overshoot, morph, fade: Animation; static let staggerStep = 0.015, waveBudget = 0.6, cascadeStep = 0.06; static func stagger(_ index: Int, of count: Int) -> Double; static func sweepDelay(hour: Int) -> Double }`
  - `extension View { func chartIntroFade(_ intro: ChartIntro?, fadeOnly: Bool = false) -> some View; func chartIntroMorph<V: Equatable>(_ intro: ChartIntro?, value: V) -> some View }`
  - `extension EnvironmentValues { var chartIntroActive: Bool }` (default `true`)
  - `struct CountUpFormat: Equatable { let source, prefix, suffix: String; let number: Double; let decimals: Int; let grouped: Bool; static func parse(_ text: String) -> CountUpFormat?; func render(_ value: Double) -> String }`
  - `struct CountUpText: View { init(text: String, intro: ChartIntro?, after: Double = 0); static func shown(_ format: CountUpFormat?, intro: ChartIntro?) -> Double }`
  - `struct CountUpNumber<Content: View>: View, Animatable { init(value: Double, @ViewBuilder content: @escaping (Int) -> Content) }`

- [ ] **Step 1: Write the failing test** — create `iphone/MakeReadyCaptureTests/ChartIntroTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import MakeReady

/// dashboard-chart-intros: the shared intro vocabulary (SPEC D3, D7, D10, D13, D14, D16).
final class ChartIntroTests: XCTestCase {

    // MARK: - D14 count-up

    func testCountUpParsesTheLeadingNumberAndKeepsItsAffixes() {
        let percent = CountUpFormat.parse("84%")
        XCTAssertEqual(percent?.number, 84)
        XCTAssertEqual(percent?.suffix, "%")
        XCTAssertEqual(percent?.decimals, 0)
        let grouped = CountUpFormat.parse("1,204")
        XCTAssertEqual(grouped?.number, 1204)
        XCTAssertEqual(grouped?.grouped, true)
        XCTAssertEqual(CountUpFormat.parse("32")?.number, 32)
        let decimal = CountUpFormat.parse("4.5")
        XCTAssertEqual(decimal?.number, 4.5)
        XCTAssertEqual(decimal?.decimals, 1)
        XCTAssertEqual(CountUpFormat.parse("12 min")?.suffix, " min")
        XCTAssertNil(CountUpFormat.parse("—"))
        XCTAssertNil(CountUpFormat.parse(""))
    }

    func testCountUpRendersTheSourceAtItsValueAndFormatsOnTheWay() {
        let grouped = CountUpFormat.parse("1,204")!
        XCTAssertEqual(grouped.render(1204), "1,204")
        XCTAssertEqual(grouped.render(602), "602")
        XCTAssertEqual(grouped.render(1100), "1,100")
        XCTAssertEqual(CountUpFormat.parse("84%")!.render(0), "0%")
        XCTAssertEqual(CountUpFormat.parse("4.5")!.render(2), "2.0")
        XCTAssertEqual(CountUpFormat.parse("12 min")!.render(6), "6 min")
    }

    func testCountUpShownValueFollowsTheIntro() {
        let format = CountUpFormat.parse("84%")
        XCTAssertEqual(CountUpText.shown(format, intro: nil), 84)
        XCTAssertEqual(CountUpText.shown(format, intro: ChartIntro(played: false)), 0)
        XCTAssertEqual(CountUpText.shown(format, intro: ChartIntro(played: true)), 84)
        // D10: no count-up under Reduce Motion — the value is final from the first frame.
        XCTAssertEqual(CountUpText.shown(format, intro: ChartIntro(played: false, reduceMotion: true)), 84)
        XCTAssertEqual(CountUpText.shown(nil, intro: ChartIntro(played: false)), 0)
    }

    // MARK: - D3 stagger

    func testStaggerIsFifteenMillisecondsAndAWaveFitsTheBudget() {
        XCTAssertEqual(ChartIntroMotion.stagger(0, of: 24), 0)
        XCTAssertEqual(ChartIntroMotion.stagger(1, of: 24), 0.015, accuracy: 1e-9)
        XCTAssertEqual(ChartIntroMotion.stagger(23, of: 24), 0.345, accuracy: 1e-9)
        XCTAssertEqual(ChartIntroMotion.stagger(87, of: 88), ChartIntroMotion.waveBudget, accuracy: 1e-9)
        XCTAssertEqual(ChartIntroMotion.stagger(200, of: 88), ChartIntroMotion.waveBudget, accuracy: 1e-9)
        XCTAssertEqual(ChartIntroMotion.stagger(3, of: 1), 0)
        XCTAssertEqual(ChartIntroMotion.sweepDelay(hour: 0), 0)
        XCTAssertEqual(ChartIntroMotion.sweepDelay(hour: 12), 0.3, accuracy: 1e-9)
    }

    // MARK: - D7 / D10 / D16 poses

    func testIntroPoses() {
        XCTAssertEqual(ChartIntro(played: false).progress(fadeOnly: false), 0)
        XCTAssertEqual(ChartIntro(played: true).progress(fadeOnly: false), 1)
        XCTAssertEqual(ChartIntro(played: false).opacity(fadeOnly: false), 1)
        // D16: an empty chart crossfades only — final geometry, opacity 0 → 1.
        XCTAssertEqual(ChartIntro(played: false).progress(fadeOnly: true), 1)
        XCTAssertEqual(ChartIntro(played: false).opacity(fadeOnly: true), 0)
        XCTAssertEqual(ChartIntro(played: true).opacity(fadeOnly: true), 1)
        // D10: Reduce Motion is the same crossfade, and nothing animates geometry.
        XCTAssertEqual(ChartIntro(played: false, reduceMotion: true).progress(fadeOnly: false), 1)
        XCTAssertEqual(ChartIntro(played: false, reduceMotion: true).opacity(fadeOnly: false), 0)
        XCTAssertNil(ChartIntro(played: true, reduceMotion: true).animation(ChartIntroMotion.rise))
        XCTAssertNil(ChartIntro(played: true, reduceMotion: true).morph)
        XCTAssertNotNil(ChartIntro(played: true).morph)
        XCTAssertEqual(ChartIntro(played: true, delay: 0.1).delayed(by: 0.2).delay, 0.3, accuracy: 1e-9)
    }

    func testScaledLengthIsTheStillLengthAtFullProgress() {
        XCTAssertEqual(ChartIntro.scaled(98, by: 0), 0)
        XCTAssertEqual(ChartIntro.scaled(98, by: 0.5), 49)
        XCTAssertEqual(ChartIntro.scaled(98, by: 1), 98)
    }
}
```

Register the test file in the `MakeReadyCaptureTests` target:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
g = p.main_group.find_subpath("MakeReadyCaptureTests", false) or abort("no group MakeReadyCaptureTests")
unless g.files.any? { |f| f.path == "ChartIntroTests.swift" }
  p.targets.find { |t| t.name == "MakeReadyCaptureTests" }.add_file_references([g.new_reference("ChartIntroTests.swift")])
end
p.save'
```

- [ ] **Step 2: Run it and watch it fail** — from the repo root, `npm run ios:build-check -- --test` → FAIL to compile: `cannot find 'CountUpFormat' in scope`, `cannot find 'ChartIntro' in scope`.

- [ ] **Step 3: Write the minimal implementation** — create `iphone/MakeReadyUI/ChartIntro.swift`:

```swift
import SwiftUI

/// dashboard-chart-intros — the intro a chart plays the first time its Home section reveals.
///
/// D7: every chart takes `ChartIntro?` and `nil` is the still render it draws today — what
/// ViewRegistry, `/compare`, the d2m fixtures and every other screen pass. A non-nil intro flips
/// `played` false → true once per visit; charts key implicit animations on that flip, so the
/// start pose animates to a final pose identical to the `nil` render. No timed choreography.
struct ChartIntro: Equatable {
    /// false = the start pose; true = the final pose (the `nil` render).
    var played: Bool
    /// D10: crossfade only — no scale, translation, sweep, wave or count-up; data changes snap.
    var reduceMotion: Bool = false
    /// Seconds before this chart's first element moves (a rail card's cascade, D8).
    var delay: Double = 0

    /// 0 = start pose, 1 = final pose. D10/D16: a fade-only intro is final from the first frame.
    func progress(fadeOnly: Bool) -> Double {
        (fadeOnly || reduceMotion || played) ? 1 : 0
    }

    /// The crossfade (D10/D16): 0 until played, for a fade-only intro; otherwise always 1.
    func opacity(fadeOnly: Bool) -> Double {
        (fadeOnly || reduceMotion) && !played ? 0 : 1
    }

    /// One element's intro animation, `extra` seconds after this chart's own delay — nil under
    /// Reduce Motion, so geometry never moves (D10).
    func animation(_ base: Animation, after extra: Double = 0) -> Animation? {
        reduceMotion ? nil : base.delay(delay + extra)
    }

    /// D9: data behind a played chart moves old → new; D10: it snaps under Reduce Motion.
    var morph: Animation? { reduceMotion ? nil : ChartIntroMotion.morph }

    /// The same intro, starting `extra` seconds later (a card forwarding to its chart).
    func delayed(by extra: Double) -> ChartIntro {
        ChartIntro(played: played, reduceMotion: reduceMotion, delay: delay + extra)
    }

    /// A length at intro progress `progress` — the still length at 1.
    static func scaled(_ length: CGFloat, by progress: Double) -> CGFloat {
        length * CGFloat(progress)
    }
}

// GAP — Token.Motion has no chart-intro entries (dashboard-chart-intros D12/D13); the owner
// files rise, draw, count-up, overshoot and morph in the d2m token register. Tokens.swift is
// generated and is not edited. Values tuned at the walk within D3 (each intro ≤ 1.2 s).
enum ChartIntroMotion {
    static let rise = Animation.spring(duration: 0.6, bounce: 0.15)
    static let draw = Animation.easeOut(duration: 0.5)
    static let countUp = Animation.easeOut(duration: 0.8)
    static let overshoot = Animation.spring(duration: 0.8, bounce: 0.25)
    static let morph = Animation.easeInOut(duration: 0.4)
    /// D10: the Reduce Motion / empty-chart crossfade.
    static let fade = Animation.easeOut(duration: 0.2)

    /// D3: ≈ 15 ms between bars…
    static let staggerStep: Double = 0.015
    /// …shrunk so the last bar of any wave starts by 0.6 s, leaving the rise inside 1.2 s.
    static let waveBudget: Double = 0.6
    /// D8: between rail cards in a cascade.
    static let cascadeStep: Double = 0.06

    /// The delay of element `index` in a left-to-right wave of `count`.
    static func stagger(_ index: Int, of count: Int) -> Double {
        guard count > 1, index > 0 else { return 0 }
        let step = min(staggerStep, waveBudget / Double(count - 1))
        return Double(min(index, count - 1)) * step
    }

    /// D2 Sessions: when the clock's sweep reaches `hour` (0 = midnight) — the same 0.6 s the
    /// TimeActivityChart's wave spans, so the two move in step.
    static func sweepDelay(hour: Int) -> Double {
        Double(min(max(hour, 0), 24)) / 24 * waveBudget
    }
}

extension View {
    /// D10/D16: the crossfade. Inert when `intro` is nil.
    func chartIntroFade(_ intro: ChartIntro?, fadeOnly: Bool = false) -> some View {
        opacity(intro?.opacity(fadeOnly: fadeOnly) ?? 1)
            .animation(intro == nil ? nil : ChartIntroMotion.fade, value: intro?.played)
    }

    /// D9: the morph when the data behind a chart changes. No animation with no intro.
    func chartIntroMorph<V: Equatable>(_ intro: ChartIntro?, value: V) -> some View {
        animation(intro?.morph, value: value)
    }
}

extension EnvironmentValues {
    /// D6/D15 (revised 2026-10-26): whether the Home tab is the selected tab. The shell sets it
    /// from `UI2ShellModel.homeActive`; every other host leaves the default.
    @Entry var chartIntroActive: Bool = true
}
```

Create `iphone/MakeReadyUI/CountUp.swift`:

```swift
import SwiftUI

/// dashboard-chart-intros D14: a value string split around its leading number. The prefix is
/// whatever precedes the first digit, the suffix whatever follows the number — both kept verbatim.
struct CountUpFormat: Equatable {
    let source: String
    let prefix: String
    let number: Double
    let decimals: Int
    let grouped: Bool
    let suffix: String

    /// nil when the string holds no number — the caller fades it in instead (D14).
    static func parse(_ text: String) -> CountUpFormat? {
        let chars = Array(text)
        guard let start = chars.firstIndex(where: isDigit) else { return nil }
        var index = start
        var digits = ""
        var grouped = false
        while index < chars.count {
            if isDigit(chars[index]) {
                digits.append(chars[index])
                index += 1
            } else if chars[index] == ",", isGroup(chars, at: index + 1) {
                grouped = true
                index += 1
            } else {
                break
            }
        }
        var decimals = 0
        if index + 1 < chars.count, chars[index] == ".", isDigit(chars[index + 1]) {
            digits.append(".")
            index += 1
            while index < chars.count, isDigit(chars[index]) {
                digits.append(chars[index])
                decimals += 1
                index += 1
            }
        }
        guard let number = Double(digits) else { return nil }
        return CountUpFormat(
            source: text,
            prefix: String(chars[..<start]),
            number: number,
            decimals: decimals,
            grouped: grouped,
            suffix: String(chars[index...])
        )
    }

    /// The string at `value` — exactly `source` at the parsed number.
    func render(_ value: Double) -> String {
        guard value != number else { return source }
        let style = FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(decimals))
            .grouping(grouped ? .automatic : .never)
            .locale(Locale(identifier: "en_US"))  // "," grouping, "." decimals — the dashboard's strings
        return prefix + value.formatted(style) + suffix
    }

    private static func isDigit(_ char: Character) -> Bool { char.isASCII && char.isNumber }

    /// A grouping comma is followed by exactly three digits.
    private static func isGroup(_ chars: [Character], at start: Int) -> Bool {
        guard start + 3 <= chars.count, chars[start..<start + 3].allSatisfy(isDigit) else { return false }
        return start + 3 == chars.count || !isDigit(chars[start + 3])
    }
}

/// D14: a value string whose number counts up from 0 when its intro plays and moves old → new
/// when it changes after (D9). A string with no number fades in instead. Style it like a Text —
/// `designTextStyle` and `foregroundColor` are View modifiers.
struct CountUpText: View {
    let text: String
    let intro: ChartIntro?
    var after: Double = 0

    var body: some View {
        let format = CountUpFormat.parse(text)
        CountUpLabel(text: text, shown: Self.shown(format, intro: intro))
            .animation(intro?.animation(ChartIntroMotion.countUp, after: after), value: intro?.played)
            .chartIntroMorph(intro, value: text)
            .chartIntroFade(intro, fadeOnly: format == nil)
    }

    /// The number shown before animation: the final value with no intro or once played.
    static func shown(_ format: CountUpFormat?, intro: ChartIntro?) -> Double {
        guard let format else { return 0 }
        return format.number * (intro?.progress(fadeOnly: false) ?? 1)
    }
}

/// Interpolates `shown` frame by frame — `.contentTransition(.numericText())` alone animates the
/// glyph swap, not the values in between (audit F6).
private struct CountUpLabel: View, Animatable {
    let text: String
    var shown: Double

    var animatableData: Double {
        get { shown }
        set { shown = newValue }
    }

    var body: some View {
        Text(CountUpFormat.parse(text)?.render(shown) ?? text)
    }
}

/// D14 for a view that takes an Int (C-031's PercentDisc): `content` is rebuilt with the
/// interpolated value every frame.
struct CountUpNumber<Content: View>: View, Animatable {
    var value: Double
    let content: (Int) -> Content

    init(value: Double, @ViewBuilder content: @escaping (Int) -> Content) {
        self.value = value
        self.content = content
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { content(Int(value.rounded())) }
}
```

Sync the two new sources into the `MakeReadyUI` + `MakeReady` targets, then mirror into `MakeReadyCapture`:

```bash
ruby iphone/scripts/makereadyui-sync.rb && ruby iphone/scripts/capture-targets.rb && ruby iphone/scripts/capture-targets.rb --check
```
→ the sync lists `ChartIntro.swift` and `CountUp.swift` as added; `--check` exits 0.

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the six `ChartIntroTests` plus every existing test); then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `git add iphone/MakeReadyUI/ChartIntro.swift iphone/MakeReadyUI/CountUp.swift iphone/MakeReadyCaptureTests/ChartIntroTests.swift iphone/MakeReady.xcodeproj/project.pbxproj` → `feat(dashboard-chart-intros): ChartIntro, motion values and the count-up`

### Task 2: The played ledger and the shell's homeActive signal
App: iphone
Phase: 1
Recipe: /nav-route — the shell model and its tab routing (`UI2ShellModel.apply`); SPEC D4, D5, D6, D15 (revised 2026-10-26), audit F4/F8.
Build-time risk (F10): whether `onScrollVisibilityChange` reports a section already above the fold when Home first appears (Following sits first, so Overview may start partly visible). The ledger is indifferent to it — it plays whatever is reported visible while active — and Task 7 plus walk step 1 settle the reporting.

**Files:**
- Create: `iphone/MakeReadyUI/ChartIntroLedger.swift`
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift` (add `homeActive` beside `tab`/`section`, ~line 28)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:88-104` (`stack(for:)` — one environment line)
- Modify: `iphone/MakeReadyCaptureTests/ChartIntroTests.swift` (append tests)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (via the sync scripts)

**Interfaces:**
- Consumes: `EnvironmentValues.chartIntroActive` (Task 1).
- Produces:
  - `struct ChartIntroLedger: Equatable { enum Section: String, CaseIterable { case overview, activity, sessions, engagement }; func hasPlayed(_ section: Section) -> Bool; mutating func setVisible(_ section: Section, _ isVisible: Bool); mutating func setActive(_ isActive: Bool) }`
  - `UI2ShellModel.homeActive: Bool` (computed, `tab == .home`)

- [ ] **Step 1: Write the failing test** — append to `ChartIntroTests` (inside the class):

```swift
    // MARK: - D5 / D6 / D15 the played ledger

    func testASectionPlaysOnceAndNotAgainOnScrollBack() {
        var ledger = ChartIntroLedger()
        XCTAssertFalse(ledger.hasPlayed(.sessions))
        ledger.setVisible(.sessions, true)
        XCTAssertTrue(ledger.hasPlayed(.sessions))
        ledger.setVisible(.sessions, false)
        ledger.setVisible(.sessions, true)
        XCTAssertTrue(ledger.hasPlayed(.sessions))
        XCTAssertFalse(ledger.hasPlayed(.engagement))
    }

    /// F4 + D15: Home sits hidden under another tab with its geometry unchanged, so leaving
    /// clears every flag and returning replays only what is still on screen.
    func testLeavingHomeClearsAndReturningReplaysTheVisibleSections() {
        var ledger = ChartIntroLedger()
        ledger.setVisible(.overview, true)
        ledger.setVisible(.overview, false)
        ledger.setVisible(.activity, true)
        ledger.setActive(false)
        XCTAssertFalse(ledger.hasPlayed(.overview))
        XCTAssertFalse(ledger.hasPlayed(.activity))
        ledger.setActive(true)
        XCTAssertTrue(ledger.hasPlayed(.activity))
        XCTAssertFalse(ledger.hasPlayed(.overview))
    }

    /// D6: a pushed page or a menu over Home never reports Home inactive — a repeated `true`
    /// changes nothing.
    func testARepeatedActiveSignalChangesNothing() {
        var ledger = ChartIntroLedger()
        ledger.setVisible(.overview, true)
        ledger.setVisible(.overview, false)
        ledger.setActive(true)
        XCTAssertTrue(ledger.hasPlayed(.overview))
    }

    func testNothingPlaysWhileHomeIsHidden() {
        var ledger = ChartIntroLedger()
        ledger.setActive(false)
        ledger.setVisible(.engagement, true)
        XCTAssertFalse(ledger.hasPlayed(.engagement))
        ledger.setActive(true)
        XCTAssertTrue(ledger.hasPlayed(.engagement))
    }

    func testHomeActiveFollowsTheSelectedTab() {
        var model = UI2ShellModel()
        XCTAssertTrue(model.homeActive)
        model.apply(.tab(.profile))
        XCTAssertFalse(model.homeActive)
        model.apply(.tab(.home))
        XCTAssertTrue(model.homeActive)
        model.apply(.section(.members))
        model.apply(.tab(.home))                // a re-tap of Home
        XCTAssertTrue(model.homeActive)
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: `cannot find 'ChartIntroLedger' in scope`, `value of type 'UI2ShellModel' has no member 'homeActive'`.

- [ ] **Step 3: Write the minimal implementation** — create `iphone/MakeReadyUI/ChartIntroLedger.swift`:

```swift
import SwiftUI

/// dashboard-chart-intros D5/D6/D15: which Home sections have played their intro this visit.
/// View state on HomeDashboardScreen (`@State`) — nothing else reads it and it is not persisted.
struct ChartIntroLedger: Equatable {
    enum Section: String, CaseIterable {
        case overview, activity, sessions, engagement
    }

    private(set) var played: Set<Section> = []
    /// The sections ≥ 50 % visible right now (D4), kept so a return to Home can replay them.
    private(set) var visible: Set<Section> = []
    /// D15: false while another tab is selected.
    private(set) var active = true

    func hasPlayed(_ section: Section) -> Bool { played.contains(section) }

    /// D4/D5: a section crossed the 50 % line. It plays the first time it is seen this visit.
    mutating func setVisible(_ section: Section, _ isVisible: Bool) {
        if isVisible {
            visible.insert(section)
            if active { played.insert(section) }
        } else {
            visible.remove(section)
        }
    }

    /// D6/D15: leaving Home clears every flag while the page is hidden; returning plays the
    /// sections still on screen (their visibility never changed, audit F4).
    mutating func setActive(_ isActive: Bool) {
        guard isActive != active else { return }
        active = isActive
        played = isActive ? visible : []
    }
}
```

In `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift`, under `var section: UI2Section = .home` add:

```swift
    /// dashboard-chart-intros D6/D15: Home is the selected tab. A push or a Home re-tap keeps it
    /// true; selecting another tab makes it false, which resets the dashboard's chart intros.
    var homeActive: Bool { tab == .home }
```

In `iphone/MakeReady/UI2/Shell/UI2Shell.swift` `stack(for:)`, after the `.environment(\.ui2Navigator, …)` modifier add:

```swift
        // dashboard-chart-intros D15: the dashboard resets its intros while hidden, replays on return.
        .environment(\.chartIntroActive, model.homeActive)
```

Sync the new MakeReadyUI source:

```bash
ruby iphone/scripts/makereadyui-sync.rb && ruby iphone/scripts/capture-targets.rb && ruby iphone/scripts/capture-targets.rb --check
```
→ `ChartIntroLedger.swift` added; `--check` exits 0.

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (five new tests plus every `UI2ShellModelTests` case); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `git add iphone/MakeReadyUI/ChartIntroLedger.swift iphone/MakeReady/UI2/Shell/UI2ShellModel.swift iphone/MakeReady/UI2/Shell/UI2Shell.swift iphone/MakeReadyCaptureTests/ChartIntroTests.swift iphone/MakeReady.xcodeproj/project.pbxproj` → `feat(dashboard-chart-intros): played ledger and the shell's homeActive visit signal`

### Task 3: C-024 SparkBarChart and C-023 RailCard intros
App: iphone
Phase: 2
Recipe: /transition-review — implicit `.animation(_:value:)` on the `played` flip; SPEC §iphone component table rows C-024 and C-023, D2, D3, D7, D8, D9, D12, D16.
Build-time risk (F11): per-frame cost of 24-bar waves on the lazy day rail — `/animation-debug` if the walk shows a stutter.

**Files:**
- Modify: `iphone/MakeReadyUI/SparkBarChart.swift` (props after `averageLabelSide`; `body`; `barRow`; `averageAnnotation`; `hairline`)
- Modify: `iphone/MakeReadyUI/RailCard.swift` (props after `detailsState`; `metricCard`; `dayBodySlot`)
- Modify: `iphone/MakeReadyCaptureTests/ChartIntroTests.swift` (append tests)

**Interfaces:**
- Consumes: `ChartIntro`, `ChartIntroMotion`, `chartIntroFade`, `chartIntroMorph`, `CountUpText` (Task 1).
- Produces: `SparkBarChart(… , intro: ChartIntro? = nil)` and `RailCard(… , intro: ChartIntro? = nil)` — trailing memberwise properties, every existing call site compiles unchanged. `static func SparkBarChart.isEmptySeries(_ series: [Double]) -> Bool`; `static func RailCard.introOffset(progress: Double) -> CGFloat`.
- The spec's `SparkIntro` `.rise` / `.expand` is carried by the chart's existing `align`: a bottom-aligned row (metric cards) rises from its baseline, a centre-aligned row (day cards) expands from its midline — one `intro` prop, no enum.

- [ ] **Step 1: Write the failing test** — append to `ChartIntroTests`:

```swift
    // MARK: - Task 3: C-024 / C-023

    func testSparkBarChartTreatsAnAllZeroSeriesAsEmpty() {
        XCTAssertTrue(SparkBarChart.isEmptySeries([]))
        XCTAssertTrue(SparkBarChart.isEmptySeries([0, 0, 0]))
        XCTAssertFalse(SparkBarChart.isEmptySeries([0, 2, 0]))
    }

    func testRailCardRisesEightPointsIntoPlace() {
        XCTAssertEqual(RailCard.introOffset(progress: 0), 8)
        XCTAssertEqual(RailCard.introOffset(progress: 0.5), 4)
        XCTAssertEqual(RailCard.introOffset(progress: 1), 0)
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: `type 'SparkBarChart' has no member 'isEmptySeries'`.

- [ ] **Step 3: Write the minimal implementation**

`SparkBarChart.swift` — after `let averageLabelSide: LabelSide` add:

```swift
    // GAP — C-024: no contract prop for the intro (dashboard-chart-intros D12).
    /// dashboard-chart-intros: nil = the still render (D7). Bars grow toward their `align` edge in
    /// a left-to-right wave, then the average line draws across.
    var intro: ChartIntro? = nil

    /// D16: nothing to wave over — the chart crossfades only.
    static func isEmptySeries(_ series: [Double]) -> Bool { !series.contains { $0 > 0 } }

    private var introProgress: Double {
        intro?.progress(fadeOnly: Self.isEmptySeries(series)) ?? 1
    }
```

In `body`, replace the trailing `.ui2Element("SparkBarChart")` line with:

```swift
        .chartIntroMorph(intro, value: series)        // D9
        .chartIntroFade(intro, fadeOnly: Self.isEmptySeries(series))
        .ui2Element("SparkBarChart")                  // capture element map — UI2Element.swift
```

In `barRow(_:metrics:height:)`, replace the bar's `.frame(width:height:)` line with:

```swift
                    .frame(
                        width: metrics.barWidth,
                        height: ChartIntro.scaled(barHeight(value, of: bars, in: height), by: introProgress)
                    )
                    .animation(
                        intro?.animation(ChartIntroMotion.rise, after: ChartIntroMotion.stagger(index, of: bars.count)),
                        value: intro?.played
                    )
```

In `averageAnnotation(_:size:)`, add after each branch's `VStack { … }` chain (both the `.top` and the else branch) — simplest as one modifier on the whole `@ViewBuilder` result by wrapping the body in a `Group { … }`:

```swift
        Group {
            // …the existing if/else, unchanged…
        }
        .opacity(introProgress)
        .animation(
            intro?.animation(ChartIntroMotion.draw, after: ChartIntroMotion.stagger(bars.count - 1, of: bars.count)),
            value: intro?.played
        )
```

In `hairline(width:)`, trim the path before stroking so the line draws across:

```swift
        Path { path in
            path.move(to: CGPoint(x: 0, y: Self.hairlineWidth / 2))
            path.addLine(to: CGPoint(x: width, y: Self.hairlineWidth / 2))
        }
        .trim(from: 0, to: introProgress)
        .stroke(
            Token.white50,
            style: StrokeStyle(lineWidth: Self.hairlineWidth, dash: Self.hairlineDash)
        )
```

`RailCard.swift` — after `var detailsState: ValuePair.State? = nil` add:

```swift
    // GAP — C-023: no contract prop for the intro (dashboard-chart-intros D12).
    /// dashboard-chart-intros: nil = the still render (D7). `intro.delay` is the card's place in
    /// its rail's cascade (D8), set by the screen.
    var intro: ChartIntro? = nil

    // GAP — no spacing token for the cascade's 8pt rise (dashboard-chart-intros §iphone C-023).
    private static let introRise: CGFloat = 8
    /// The card's vertical offset at intro progress `progress`.
    static func introOffset(progress: Double) -> CGFloat { introRise * CGFloat(1 - progress) }

    private var introProgress: Double { intro?.progress(fadeOnly: false) ?? 1 }
```

In `metricCard`: pass `intro: intro?.delayed(by: 0.1)` as the last argument of its `SparkBarChart(…)`; replace the value `Text(value ?? "")` with `CountUpText(text: value ?? "", intro: intro, after: 0.1)` keeping every modifier that followed it; add to the `TrendIndicator(…)` before `.ui2Element("Trend")`:

```swift
                .scaleEffect(0.6 + 0.4 * introProgress, anchor: .leading)
                .opacity(introProgress)
                .animation(intro?.animation(ChartIntroMotion.overshoot, after: 0.3), value: intro?.played)
```

and append to the end of `metricCard`'s chain (after `.clipShape(…)`):

```swift
        .offset(y: Self.introOffset(progress: introProgress))
        .opacity(intro == nil ? 1 : introProgress)
        .animation(intro?.animation(ChartIntroMotion.rise), value: intro?.played)
        .chartIntroFade(intro)
```

In `dayBodySlot`, pass `intro: intro` as the last argument of the `SparkBarChart(…)` in the `.standard, .transparent` case (the centre-aligned row expands from its midline); `.percentCircle` is unchanged.

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; `git diff --stat -- iphone/MakeReadyCaptureTests/ViewRegistry.swift capture/fixtures` → empty (D7: no capture passes an intro).

- [ ] **Step 5: Commit** — `git add iphone/MakeReadyUI/SparkBarChart.swift iphone/MakeReadyUI/RailCard.swift iphone/MakeReadyCaptureTests/ChartIntroTests.swift` → `feat(dashboard-chart-intros): SparkBarChart wave and RailCard cascade intros`

### Task 4: C-026 DualSeriesBarChart intro
App: iphone
Phase: 2
Recipe: /transition-review — SPEC §iphone row C-026, D2, D3, D7, D9, D16.
Build-time risk (F11): the chart is a `HorizontalRail` of every day in history; only the window's columns are on screen, the rest animate unseen — `/animation-debug` if the walk shows a stutter.

**Files:**
- Modify: `iphone/MakeReadyUI/DualSeriesBarChart.swift` (init; `body`; `columns(_:column:)`; `bar(_:isFuture:max:)`; `todayOverlay(_:column:pitch:)`; the gridline/badge block in `body`)
- Modify: `iphone/MakeReadyCaptureTests/ChartIntroTests.swift` (append tests)

**Interfaces:**
- Consumes: `ChartIntro`, `ChartIntroMotion`, `chartIntroFade`, `chartIntroMorph` (Task 1).
- Produces: `DualSeriesBarChart(days:window:today:onWindowChange:recenterRequest:recenterAnimation:intro:)` — `intro: ChartIntro? = nil` last, existing calls unchanged. `static func DualSeriesBarChart.introColumnHeight(_ value: Int, max: Int, progress: Double) -> CGFloat`; `static func DualSeriesBarChart.introSettle(windowLength: Int) -> Double`.

- [ ] **Step 1: Write the failing test** — append to `ChartIntroTests`:

```swift
    // MARK: - Task 4: C-026

    func testDualSeriesColumnsRiseToTheirStillHeight() {
        XCTAssertEqual(DualSeriesBarChart.introColumnHeight(10, max: 10, progress: 0), 0)
        XCTAssertEqual(DualSeriesBarChart.introColumnHeight(10, max: 10, progress: 0.5), 49)
        XCTAssertEqual(DualSeriesBarChart.introColumnHeight(10, max: 10, progress: 1), 98)
        XCTAssertEqual(DualSeriesBarChart.introColumnHeight(5, max: 0, progress: 1), 0)
    }

    /// D3: the today rule and badge wait for the sweep, but never past 0.4 s, so the badge's
    /// rise still lands inside 1.2 s however long the window is.
    func testDualSeriesTodayWaitsForTheSweepWithinTheBudget() {
        XCTAssertEqual(DualSeriesBarChart.introSettle(windowLength: 7), 0.09, accuracy: 1e-9)
        XCTAssertEqual(DualSeriesBarChart.introSettle(windowLength: 60), 0.4, accuracy: 1e-9)
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: `type 'DualSeriesBarChart' has no member 'introColumnHeight'`.

- [ ] **Step 3: Write the minimal implementation** — in `DualSeriesBarChart.swift`:

Add the stored property after `let recenterAnimation: Animation`:

```swift
    // GAP — C-026: no contract prop for the intro (dashboard-chart-intros D12).
    /// dashboard-chart-intros: nil = the still render (D7). Columns sweep in toward today, the
    /// completed fill climbs after, then the today rule drops and its badge pops.
    let intro: ChartIntro?
```

Add `intro: ChartIntro? = nil` as the init's last parameter and `self.intro = intro` as its last line.

Add the helpers beside `columnHeight`:

```swift
    /// A column's height at intro progress `progress` — the still height at 1.
    static func introColumnHeight(_ value: Int, max maxScheduled: Int, progress: Double) -> CGFloat {
        ChartIntro.scaled(columnHeight(value, max: maxScheduled), by: progress)
    }

    /// D3: when the today rule starts — after the sweep reaches the window's right edge, capped
    /// at 0.4 s so the badge's 0.6 s rise ends by 1.1 s.
    static func introSettle(windowLength: Int) -> Double {
        min(ChartIntroMotion.stagger(windowLength - 1, of: windowLength), 0.4)
    }
```

In `body`, after `let shown = …` add `let progress = intro?.progress(fadeOnly: !line.hasData) ?? 1`, pass `progress` into `columns(line, column: column, progress: progress)`, wrap the four gridline/badge views of `if line.hasData { … }` so the block ends with:

```swift
                    if line.hasData {
                        Group {
                            // …the two gridlines and two badges, unchanged…
                        }
                        .opacity(progress)
                        .animation(intro?.animation(ChartIntroMotion.draw), value: intro?.played)
                    }
```

and before `.ui2Element("DualSeriesBarChart")` add:

```swift
        .chartIntroMorph(intro, value: days)              // D9
        .chartIntroFade(intro, fadeOnly: !line.hasData)   // D16
```

Change `columns` to take the progress and give each column its place in the sweep:

```swift
    private func columns(_ line: Timeline, column: CGFloat, progress: Double) -> some View {
        let pitch = column + Token.Space.chipGap
        return HStack(alignment: .bottom, spacing: Token.Space.chipGap) {
            ForEach(line.dates.indices, id: \.self) { index in
                // D2: the sweep runs left to right across the window and ends at today.
                let wave = ChartIntroMotion.stagger(max(index - line.windowStart, 0), of: line.windowLength)
                Group {
                    if line.hasData {
                        bar(line.entries[index], isFuture: line.dates[index] > today, max: line.maxScheduled,
                            progress: progress, wave: wave)
                    } else {
                        Rectangle()
                            .fill(Token.white20)
                            .frame(height: Geometry.emptyStubHeight)
                    }
                }
                // …the existing .frame / .ui2Element / .id lines, unchanged…
            }
        }
        // …the existing .scrollTargetLayout / .padding lines, unchanged…
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                tickLabels(line, pitch: pitch)
                if line.hasData { todayOverlay(line, column: column, pitch: pitch, progress: progress) }
            }
        }
        .ui2Element("Column plot area")
    }
```

Change `bar` so the scheduled column rises on its wave and the completed fill climbs 0.15 s after:

```swift
    private func bar(_ day: Day?, isFuture: Bool, max maxScheduled: Int, progress: Double, wave: Double) -> some View {
        let completed = isFuture ? 0 : min(day?.completed ?? 0, day?.scheduled ?? 0)
        return ZStack(alignment: .bottom) {
            Rectangle().fill(Token.white20)
            Rectangle()
                .fill(Token.accent)
                .frame(height: Self.introColumnHeight(completed, max: maxScheduled, progress: progress))
                .animation(intro?.animation(ChartIntroMotion.draw, after: wave + 0.15), value: intro?.played)
        }
        .frame(height: Self.introColumnHeight(day?.scheduled ?? 0, max: maxScheduled, progress: progress))
        .clipped()
        .animation(intro?.animation(ChartIntroMotion.rise, after: wave), value: intro?.played)
    }
```

Change `todayOverlay` to take `progress: Double`; the rule drops from the top and the badge pops after it:

```swift
    @ViewBuilder
    private func todayOverlay(_ line: Timeline, column: CGFloat, pitch: CGFloat, progress: Double) -> some View {
        if let index = line.todayIndex {
            let ruleX = CGFloat(index) * pitch + column + (Token.Space.chipGap - Geometry.todayRuleWidth) / 2
            let settle = Self.introSettle(windowLength: line.windowLength)
            Rectangle()
                .fill(Token.highlight)
                .frame(width: Geometry.todayRuleWidth, height: Geometry.plotHeight)
                .scaleEffect(x: 1, y: progress, anchor: .top)
                .animation(intro?.animation(ChartIntroMotion.draw, after: settle), value: intro?.played)
                .offset(x: ruleX, y: Geometry.highGridlineY)
                .ui2Element("Today rule")
            Text("TODAY")
                .designTextStyle(Self.todayLabelStyle)
                .foregroundStyle(Token.highlight)
                .fixedSize()
                .scaleEffect(0.6 + 0.4 * progress, anchor: .trailing)
                .opacity(progress)
                .animation(intro?.animation(ChartIntroMotion.rise, after: settle + 0.1), value: intro?.played)
                .frame(width: ruleX, height: Geometry.badgeHeight, alignment: .trailing)
                .offset(y: Geometry.todayLabelY)
                .ui2Element("TODAY label")
        }
    }
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; `git diff --stat -- iphone/MakeReadyCaptureTests/ViewRegistry.swift capture/fixtures` → empty.

- [ ] **Step 5: Commit** — `git add iphone/MakeReadyUI/DualSeriesBarChart.swift iphone/MakeReadyCaptureTests/ChartIntroTests.swift` → `feat(dashboard-chart-intros): DualSeriesBarChart sweep, fill and today intros`

### Task 5: C-029 RadialDayClock and C-030 TimeActivityChart intros
App: iphone
Phase: 2
Recipe: /transition-review — SPEC §iphone rows C-029 and C-030, D2 (the sweep sets arc order, each arc blooms when reached), D3, D7, D9, D14, D16.
Build-time risk (F11): 88 TimeActivityChart bars drawn twice (gradient mask + hidden element-map copy) — `/animation-debug` if the walk shows a stutter.

**Files:**
- Modify: `iphone/MakeReadyUI/RadialDayClock.swift` (init; `body`; `activityArcs`; `tickDots`; `centerKeyValue`)
- Modify: `iphone/MakeReadyUI/TimeActivityChart.swift` (init; `body`; `barRow`)
- Modify: `iphone/MakeReadyCaptureTests/ChartIntroTests.swift` (append tests)

**Interfaces:**
- Consumes: `ChartIntro`, `ChartIntroMotion` (incl. `sweepDelay(hour:)`), `chartIntroFade`, `chartIntroMorph`, `CountUpText` (Task 1).
- Produces: `RadialDayClock(hourValues:centerValue:centerUnit:centerCaption:intro:)` and `TimeActivityChart(bins:tickLabels:intro:)`, `intro: ChartIntro? = nil` last. `static func RadialDayClock.bloomScale(progress: Double) -> CGFloat`.

- [ ] **Step 1: Write the failing test** — append to `ChartIntroTests`:

```swift
    // MARK: - Task 5: C-029 / C-030

    func testRadialArcsBloomFromEightyFivePercent() {
        XCTAssertEqual(RadialDayClock.bloomScale(progress: 0), 0.85, accuracy: 1e-9)
        XCTAssertEqual(RadialDayClock.bloomScale(progress: 0.5), 0.925, accuracy: 1e-9)
        XCTAssertEqual(RadialDayClock.bloomScale(progress: 1), 1, accuracy: 1e-9)
    }

    /// D2: the bar chart grows in step with the clock — its last bin starts when the sweep
    /// reaches midnight again.
    func testTimeActivityWaveEndsWithTheClockSweep() {
        XCTAssertEqual(ChartIntroMotion.stagger(87, of: 88), ChartIntroMotion.sweepDelay(hour: 24), accuracy: 1e-9)
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: `type 'RadialDayClock' has no member 'bloomScale'`.

- [ ] **Step 3: Write the minimal implementation**

`RadialDayClock.swift` — add after `let centerCaption: String`:

```swift
    // GAP — C-029: no contract prop for the intro (dashboard-chart-intros D12).
    /// dashboard-chart-intros: nil = the still render (D7). A clockwise sweep from midnight: each
    /// arc trims in and blooms as the sweep reaches its start hour, each hour dot lights as it is
    /// passed, and the centre value counts up.
    let intro: ChartIntro?

    /// An arc's scale at intro progress `progress` (D2's bloom).
    static func bloomScale(progress: Double) -> CGFloat { 0.85 + 0.15 * CGFloat(progress) }

    private var introProgress: Double {
        intro?.progress(fadeOnly: !hourValues.contains { $0 > 0 }) ?? 1
    }
```

Add `intro: ChartIntro? = nil` as the init's last parameter and `self.intro = intro` as its last line.

In `body`, before `.ui2Element("RadialDayClock")` add:

```swift
        .chartIntroMorph(intro, value: hourValues)                         // D9
        .chartIntroFade(intro, fadeOnly: !hourValues.contains { $0 > 0 })  // D16
```

In `activityArcs`, replace the `arcShape(run).stroke(…)` chain with:

```swift
                arcShape(run)
                    .trim(from: 0, to: introProgress)
                    .stroke(
                        run.band.color,
                        style: StrokeStyle(lineWidth: Geometry.ringStroke, lineCap: .butt)
                    )
                    .scaleEffect(Self.bloomScale(progress: introProgress))
                    .animation(
                        intro?.animation(ChartIntroMotion.draw, after: ChartIntroMotion.sweepDelay(hour: run.startHour)),
                        value: intro?.played
                    )
                    .ui2Element("Arc \(index + 1)")
```

In `tickDots`, add after each dot's `.offset(…)`:

```swift
                    .opacity(introProgress)
                    .animation(
                        intro?.animation(ChartIntroMotion.draw, after: ChartIntroMotion.sweepDelay(hour: hour)),
                        value: intro?.played
                    )
```

In `centerKeyValue`, replace `Text(centerValue)` with `CountUpText(text: centerValue, intro: intro)` keeping its three modifiers.

`TimeActivityChart.swift` — add after `let tickLabels: …`:

```swift
    // GAP — C-030: no contract prop for the intro (dashboard-chart-intros D12).
    /// dashboard-chart-intros: nil = the still render (D7). Bars rise left to right across the
    /// same 0.6 s the RadialDayClock's sweep takes (D2).
    let intro: ChartIntro?

    private var introProgress: Double {
        intro?.progress(fadeOnly: !bins.contains { $0 > 0 }) ?? 1
    }
```

Change the init to `init(bins: [Double], tickLabels: [(value: String, unit: String)], intro: ChartIntro? = nil)` with `self.intro = intro` last. In `body`, before `.ui2Element("TimeActivityChart")` add:

```swift
        .chartIntroMorph(intro, value: bins)                         // D9
        .chartIntroFade(intro, fadeOnly: !bins.contains { $0 > 0 })  // D16
```

In `barRow`, replace the bar's `.frame(width:height:)` with:

```swift
                    .frame(width: Geometry.barWidth, height: ChartIntro.scaled(height, by: introProgress))
                    .animation(
                        intro?.animation(ChartIntroMotion.rise, after: ChartIntroMotion.stagger(index, of: barHeights.count)),
                        value: intro?.played
                    )
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; `git diff --stat -- iphone/MakeReadyCaptureTests/ViewRegistry.swift capture/fixtures` → empty.

- [ ] **Step 5: Commit** — `git add iphone/MakeReadyUI/RadialDayClock.swift iphone/MakeReadyUI/TimeActivityChart.swift iphone/MakeReadyCaptureTests/ChartIntroTests.swift` → `feat(dashboard-chart-intros): RadialDayClock sweep and TimeActivityChart wave intros`

### Task 6: C-031 EnrollmentStatusRow and PercentBar intro
App: iphone
Phase: 2
Recipe: /transition-review — SPEC §iphone row C-031 (audit F5: `FillAnimation` starts in `.onAppear`, which fires at mount, off screen, and has no spring — so it is NOT used), D2, D7, D9, D10, D12 (OQ-C-031-001 stands for every caller that passes no intro, F9).

**Files:**
- Modify: `iphone/MakeReadyUI/PercentBar.swift` (props after `fillAnimation`; `shownProgress`)
- Modify: `iphone/MakeReadyUI/EnrollmentStatusRow.swift` (props after `statusColor`; `body`; `disc`; the `PercentBar(…)` in `metricsRow`)
- Modify: `iphone/MakeReadyCaptureTests/ChartIntroTests.swift` (append tests)

**Interfaces:**
- Consumes: `ChartIntro`, `ChartIntroMotion`, `chartIntroFade`, `chartIntroMorph`, `CountUpNumber` (Task 1).
- Produces: `PercentBar(…, fillAnimation:, reveal: Double? = nil)`; `EnrollmentStatusRow(…, statusColor:, intro: ChartIntro? = nil)`. `static func PercentBar.revealed(_ progress: Double, by reveal: Double) -> Double`; `static let EnrollmentStatusRow.pulsePeak: CGFloat`.

- [ ] **Step 1: Write the failing test** — append to `ChartIntroTests`:

```swift
    // MARK: - Task 6: C-031 / PercentBar

    func testPercentBarRevealScalesTheFillAndTheTrackCapsTheOvershoot() {
        XCTAssertEqual(PercentBar.revealed(0.6, by: 0), 0)
        XCTAssertEqual(PercentBar.revealed(0.6, by: 0.5), 0.3, accuracy: 1e-9)
        XCTAssertEqual(PercentBar.revealed(0.6, by: 1), 0.6, accuracy: 1e-9)
        XCTAssertEqual(PercentBar.revealed(0.9, by: 1.2), 1)
    }

    func testStatusDiscPulsesToSpecScale() {
        XCTAssertEqual(EnrollmentStatusRow.pulsePeak, 1.3)
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: `type 'PercentBar' has no member 'revealed'`.

- [ ] **Step 3: Write the minimal implementation**

`PercentBar.swift` — after `var fillAnimation: FillAnimation?` add:

```swift
    // GAP — C-057: no contract prop for an intro-driven fill (dashboard-chart-intros D12).
    /// dashboard-chart-intros: the share of `progress` the fill shows while a caller's intro
    /// plays (0 → 1, animated by the caller). nil — the default — leaves the fill exactly as
    /// `fillAnimation` and `progress` draw it.
    var reveal: Double? = nil

    /// The fill at reveal `reveal`; a spring overshoot past the track's end is capped by it.
    static func revealed(_ progress: Double, by reveal: Double) -> Double {
        min(max(progress * reveal, 0), 1)
    }
```

Replace `shownProgress` with:

```swift
    /// Prop-driven unless an animation was asked for, so a still capture is deterministic.
    private var shownProgress: Double {
        let base = fillAnimation == nil ? clampedProgress : animatedProgress
        guard let reveal else { return base }
        return Self.revealed(base, by: reveal)
    }
```

`EnrollmentStatusRow.swift` — after `let statusColor: StatusColor` add:

```swift
    // GAP — C-031: no contract prop for the intro (dashboard-chart-intros D12).
    /// dashboard-chart-intros: nil = the still render (D7, OQ-C-031-001). The bar fills from 0
    /// with a spring overshoot, the disc's percent counts up, then the disc pulses once.
    var intro: ChartIntro? = nil

    // GAP — no motion token for the status pulse (dashboard-chart-intros §iphone C-031).
    static let pulsePeak: CGFloat = 1.3

    private var introProgress: Double { intro?.progress(fadeOnly: false) ?? 1 }
```

In `body`, before `.ui2Element("EnrollmentStatusRow")` add `.chartIntroFade(intro)`.

Replace `disc` with:

```swift
    private var disc: some View {
        // D14: the percent counts up; the disc keeps its final size so nothing reflows.
        CountUpNumber(value: Double(percent) * introProgress) { shown in
            PercentDisc(percent: shown, size: Self.discSize(for: percent), statusColor: statusColor.token)
        }
        .animation(intro?.animation(ChartIntroMotion.countUp), value: intro?.played)
        .chartIntroMorph(intro, value: percent)
        // D2: one pulse after the fill settles; never under Reduce Motion (D10) or with no intro.
        .keyframeAnimator(initialValue: CGFloat(1), trigger: intro?.reduceMotion == false ? intro?.played : nil) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            LinearKeyframe(CGFloat(1), duration: 0.6)
            CubicKeyframe(Self.pulsePeak, duration: 0.15)
            CubicKeyframe(CGFloat(1), duration: 0.25)
        }
        .frame(width: Self.discSlot, height: Self.discSlot)
        .ui2Element("Disc")
    }
```

In `metricsRow`, give the `PercentBar(…)` its reveal (keep `fillAnimation: nil`) and the overshoot:

```swift
            PercentBar(
                progress: progress,
                fillColor: statusColor.token,
                size: .lg,
                aligned: .right,
                fillStyle: .solid,
                fillAnimation: nil,
                reveal: intro.map { $0.progress(fadeOnly: false) }
            )
            .animation(intro?.animation(ChartIntroMotion.overshoot), value: intro?.played)
            .chartIntroMorph(intro, value: progress)
            .frame(maxWidth: .infinity)
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; `git diff --stat -- iphone/MakeReadyCaptureTests/ViewRegistry.swift capture/fixtures` → empty.

- [ ] **Step 5: Commit** — `git add iphone/MakeReadyUI/PercentBar.swift iphone/MakeReadyUI/EnrollmentStatusRow.swift iphone/MakeReadyCaptureTests/ChartIntroTests.swift` → `feat(dashboard-chart-intros): EnrollmentStatusRow fill, count-up and pulse intro`

### Task 7: Home dashboard turns the intros on
App: iphone
Phase: 2
Recipe: /transition-review — SPEC §iphone "HomeDashboardScreen" and "Reveal modifier", D1, D4, D5, D6, D7, D8, D10, D15 (revised 2026-10-26).
Build-time risk (F10): whether `onScrollVisibilityChange(threshold: 0.5)` reports the sections already ≥ 50 % in view when Home first appears, and how it behaves inside `HomeSectionLayout`'s `ZStack` with the refresh `offset`. Settled by walk step 1; if the first-visible section never plays, seed it with `onScrollGeometryChange` on the section (a geometry read — no timed delay) and record it in the report.

**Files:**
- Modify: `iphone/MakeReadyUI/Screens/Home/HomeDashboardScreen.swift` (init `:120-137`; `@State` block `:144-153`; `body` `:207-226`; `overviewSection`; `activitySection`; `sessionsSection`; `engagementSection`)
- Modify: `iphone/MakeReady/UI2/Containers/Home/HomeDashboardContainer.swift:16-27`
- Modify: `iphone/MakeReadyCaptureTests/ChartIntroTests.swift` (append tests)

**Interfaces:**
- Consumes: `ChartIntro`, `ChartIntroMotion`, `EnvironmentValues.chartIntroActive` (Task 1); `ChartIntroLedger` (Task 2); the `intro:` props of Tasks 3–6.
- Produces: `HomeDashboardScreen(state:…, onOpenGroup:, introsEnabled: Bool = false)`; `let introsEnabled: Bool`; `static func HomeDashboardScreen.cascadeDelay(index: Int, lead: Int) -> Double`.

- [ ] **Step 1: Write the failing test** — append to `ChartIntroTests`:

```swift
    // MARK: - Task 7: HomeDashboardScreen

    /// D8: the cards on screen when a rail reveals cascade by their place from its leading
    /// card; a card past the fourth waits no longer, and one before the lead does not wait.
    func testRailCascadeDelay() {
        XCTAssertEqual(HomeDashboardScreen.cascadeDelay(index: 0, lead: 0), 0)
        XCTAssertEqual(HomeDashboardScreen.cascadeDelay(index: 2, lead: 0), 0.12, accuracy: 1e-9)
        XCTAssertEqual(HomeDashboardScreen.cascadeDelay(index: 9, lead: 0), 0.18, accuracy: 1e-9)
        XCTAssertEqual(HomeDashboardScreen.cascadeDelay(index: 182, lead: 181), 0.06, accuracy: 1e-9)
        XCTAssertEqual(HomeDashboardScreen.cascadeDelay(index: 3, lead: 5), 0)
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: `type 'HomeDashboardScreen' has no member 'cascadeDelay'`.

- [ ] **Step 3: Write the minimal implementation** — in `HomeDashboardScreen.swift`:

Add the stored flag after `var onOpenGroup: …`:

```swift
    /// dashboard-chart-intros D7: only the live app (HomeDashboardContainer) passes true; every
    /// capture, fixture and preview leaves the charts still.
    let introsEnabled: Bool
```

Add `introsEnabled: Bool = false` as the init's last parameter and `self.introsEnabled = introsEnabled` as its last line.

In the `@SwiftUI.State` block add:

```swift
    /// dashboard-chart-intros D5/D15: which sections have played this visit.
    @SwiftUI.State private var introLedger = ChartIntroLedger()
    @Environment(\.chartIntroActive) private var introActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Add the helpers in `// MARK: - Derived`:

```swift
    /// D7: nil unless the live app turned intros on.
    private func intro(_ section: ChartIntroLedger.Section, delay: Double = 0) -> ChartIntro? {
        guard introsEnabled else { return nil }
        return ChartIntro(played: introLedger.hasPlayed(section), reduceMotion: reduceMotion, delay: delay)
    }

    /// D8: a rail card's cascade delay — its place from the rail's leading card, capped at the
    /// fourth. A lazy day card built later by a swipe is created already played, so it draws final.
    static func cascadeDelay(index: Int, lead: Int) -> Double {
        Double(min(max(index - lead, 0), 3)) * ChartIntroMotion.cascadeStep
    }

    /// D4: a section starts its intro when ≥ 50 % of it is in the Home page scroll.
    private func revealsIntro(_ section: ChartIntroLedger.Section) -> some ViewModifier {
        IntroReveal(enabled: introsEnabled) { introLedger.setVisible(section, $0) }
    }
```

and at file scope, after the struct:

```swift
/// dashboard-chart-intros D4: reports a section crossing the 50 % line of the page scroll.
private struct IntroReveal: ViewModifier {
    let enabled: Bool
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        content.onScrollVisibilityChange(threshold: 0.5) { visible in
            if enabled { onChange(visible) }
        }
    }
}
```

In `body`, give each animated section its reveal and follow the shell's visit signal:

```swift
            overviewSection.modifier(revealsIntro(.overview))
            sectionDivider
            activitySection.modifier(revealsIntro(.activity))
            sectionDivider
            sessionsSection.modifier(revealsIntro(.sessions))
            sectionDivider
            engagementSection.modifier(revealsIntro(.engagement))
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: `color-layout-background`
        // D6/D15: cleared while Home sits hidden under another tab; visible sections replay on return.
        .onChange(of: introActive) { _, active in introLedger.setActive(active) }
```

(`followingSection` and the dividers get no reveal — D1.)

Pass the intros:
- `overviewSection` `RailCard(kind: .metric, …)`: last argument `intro: intro(.overview, delay: Self.cascadeDelay(index: index, lead: 0))`.
- `activitySection` day `RailCard(kind: .day, …)`: last argument `intro: intro(.activity, delay: Self.cascadeDelay(index: index, lead: railDay ?? 0))`; `DualSeriesBarChart(…)`: add `intro: intro(.activity)` after `recenterAnimation:`.
- `sessionsSection`: `RadialDayClock(…, centerCaption: state.centerCaption, intro: intro(.sessions))`; `TimeActivityChart(bins: state.bins, tickLabels: sessionTickLabels, intro: intro(.sessions))`.
- `engagementSection`: `EnrollmentStatusRow(…, statusColor: …, intro: intro(.engagement))`.

In `HomeDashboardContainer.swift`, add `introsEnabled: true` as the last argument of `HomeDashboardScreen(…)`:

```swift
            onOpenGroup: { _ in },                               // D9 no-op
            introsEnabled: true                                  // dashboard-chart-intros D7
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (every `HomeDashboardContainerTests` / `HomeDashboardMapperTests` case unchanged); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; D7 neutrality: `git diff --stat 9d794de -- iphone/MakeReadyCaptureTests/ViewRegistry.swift capture/fixtures` → empty, and `grep -rn "introsEnabled: true" iphone` → exactly one hit, in `HomeDashboardContainer.swift`.

- [ ] **Step 5: Commit** — `git add iphone/MakeReadyUI/Screens/Home/HomeDashboardScreen.swift iphone/MakeReady/UI2/Containers/Home/HomeDashboardContainer.swift iphone/MakeReadyCaptureTests/ChartIntroTests.swift` → `feat(dashboard-chart-intros): Home dashboard reveals each chart's intro once per visit`

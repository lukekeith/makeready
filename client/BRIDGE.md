# Read Activity Preview — JS ↔ Swift Bridge

`client/resources/js/preview/PreviewApp.vue` runs inside a WKWebView in
`ReadActivityPreviewModal.swift`. This document is the contract between the
two sides. Any new feature that touches the preview must update this file.

---

## Initialisation

After the HTML page loads (`webView(_:didFinish:)`), Swift calls:

```js
window.renderPreview(payload)
```

### Payload shape

```ts
interface PreviewPayload {
  blocks: Array<{
    id: string        // ActivityReadBlock.id
    content: string   // Plain text / markdown — never raw HTML
    themeSlug: string // 'none' | 'dramatic-reveal' | 'gentle-fade' |
                      // 'bold-slide' | 'typewriter' | 'star-wars'
  }>
}
```

`renderPreview` builds the full timeline, starts the RAF clock, and auto-plays.

---

## Swift → JS (evaluateJavaScript)

| Call | Effect |
|---|---|
| `window.renderPreview(payload)` | Initialise with new blocks + auto-play |
| `window.play()` | Resume RAF clock |
| `window.pause()` | Stop RAF clock, stay at current position |
| `window.seekTo(position)` | Seek to 0–1 fraction, stays paused |
| `window.scrubStart()` | User began dragging scrub bar — pause clock |
| `window.scrubEnd()` | User released scrub bar — stay paused (tap to resume) |

---

## JS → Swift (WKScriptMessage name: `"previewEvent"`)

All messages are `[String: Any]` dictionaries with a `type` key.

| `type` | Extra fields | When |
|---|---|---|
| `timeline-ready` | `totalMs: Double` | After `renderPreview` finishes building the timeline |
| `progress` | `position: Double` (0–1) | Every RAF tick (~60fps) during playback |
| `playing` | — | Clock started |
| `paused` | — | Clock stopped (scrub, scrubEnd, pause, block boundary) |
| `preview-complete` | — | Sequence reached the end |

---

## Interaction model

- **During playback**: `progress` events drive the native `UISlider` position.
- **Scrubbing**: Swift calls `scrubStart()` on `touchDown`, `seekTo(pos)` continuously on drag, `scrubEnd()` on `touchUp`. The clock stays stopped after `scrubEnd`.
- **Tap to resume**: The ThemePlayer area inside the WebView emits `toggle-playback` to the Vue clock, which resumes and sends `{ type: "playing" }` back to Swift.
- **Block boundaries**: The clock pauses automatically at each block boundary (same as `/slides`). User taps to continue.

---

## Adding new bridge calls (future features)

### Per-block background image/video
Swift sets `block.backgroundImageUrl` or `block.backgroundVideoUrl` in the payload.
`PreviewApp.vue` passes them to `ThemePlayer` via a new prop — or writes them
directly into `ThemeContext` before `theme.mount()`. No bridge protocol change needed.

### User-controlled animation timing
Swift sends `window.setThemeOverrides({ duration: 800, stagger: 200 })` before
`renderPreview`. `PreviewApp.vue` merges overrides into each block's theme definition
before building sequences.

### Scrubber phase markers
After `timeline-ready`, add a `phase-markers` message:
```js
postMessage({ type: 'phase-markers', markers: [0.12, 0.34, 0.67, ...] })
```
Swift renders tick marks on the slider track.

---

## File locations

| File | Purpose |
|---|---|
| `client/resources/js/preview/PreviewApp.vue` | Vue app — clock, timeline, ThemePlayer orchestration |
| `client/resources/js/preview-standalone.ts` | Vite entry point |
| `client/resources/preview/read-activity-preview.html` | WKWebView HTML shell (source of truth) |
| `client/vite.config.preview.ts` | Build config — single IIFE, CSS inlined |
| `scripts/copy-preview-bundle.sh` | Copies built artefacts into iPhone Resources |
| `iphone/MakeReady/Resources/read-activity-preview.html` | Built copy (committed to git) |
| `iphone/MakeReady/Resources/read-activity-preview.js` | Built copy (committed to git) |
| `iphone/MakeReady/Pages/Manage/Program/ReadActivityPreviewModal.swift` | Swift modal + WKWebView |

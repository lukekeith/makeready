# 07 — Edit-in-Place (the preview feature is retired)

## 1. Principle

**The editor renders the member pager, verbatim, plus an edit layer.** There is no separate
preview rendering path, no preview URL, no "open preview in new tab". What the leader sees while
editing *is* what the member gets, because it is the same player in edit mode — **per platform**:
the web editor wraps the Vue pager (this doc's component sketch); the iPhone editors wrap the
native pager (§6), staying management-optimized and fully native. Leaders on iPhone never edit
or view the Vue experience.

```
<LessonPager :lesson="draft" mode="edit">   ← same components as member runtime
  EditLayer                                  ← only mounts in edit mode
  ├── SelectionOutline        (tap any element → outline + inspector opens)
  ├── InlineTextEditing       (contenteditable swap for text nodes)
  ├── PageRail                (left-edge thumbnail rail: reorder pages by drag, + to insert)
  ├── InspectorSheet          (per-type fields that aren't tappable: URLs, advance rules, help text)
  └── EditorChrome            (Done/save state, undo, page count — replaces member X/mute chrome)
```

## 2. How editing maps onto the pager

- **Purity requirement:** every page component from 03/06 must be pure — content + palette in,
  events out, no data fetching, no member-progress writes. That is the entire enabler; the edit
  layer wraps the same components with selection handlers via provide/inject (`editContext`),
  and member mode simply doesn't provide it.
- **Tap-to-edit routing** (per element):
  - text (body, eyebrow, citation-style, overlay text, prompt, placeholder) → inline
    contenteditable with the palette's real typography; Enter/blur commits to the draft store.
  - background / backdrop → background inspector (color, media picker, scrim slider, per-page vs
    lesson scope toggle).
  - video/image/youtube media → media picker / record / URL sheet.
  - Bible passage → passage picker (existing twin).
  - exegesis highlight → floating card in edit mode (06).
  - action buttons → action inspector (add/remove `ADD_TO_PRAYER_LIST`, label).
- **Behavioral toggles** live in the inspector, not on canvas: `advanceRule`, `revealMode`,
  `layout`, `scale`, theme/motion preset.
- **Entrance animations in edit mode:** play once on page-settle exactly like member mode (this
  IS the preview), with a rail control "replay entrance". Word-reveal pages show fully revealed
  after the first play; replay control re-runs it.
- **Gating is not enforced** in edit mode (leaders scroll freely past locked pages); a chip on
  the page notes "advances after video" etc.

## 3. Draft/save model

- Edit operates on the draft store (existing `activity-editor-actions.ts` seam extended for the
  new fields): optimistic per-field PATCH exactly like today's panes — tri-state save chip
  (saved / saving / error) in `EditorChrome`, matching the established editor pattern.
- Publish/versioning flow unchanged (`StudyProgramVersion` snapshots now include presentation
  fields; content hash extends over them — coordinate with the highlighting hash rules).
- Scheduled-copy editing (enrollment editors) uses the same surface via the existing
  scheduled-activity factories.

## 4. What replaces preview's remaining jobs

| Old preview job | Replacement |
|---|---|
| "See what members see" (desktop leaders) | The web editor itself (identical rendering) |
| iPhone leader preview (`ReadActivityPreviewModal.swift` WKWebView) | The **native pager in edit/walkthrough mode** (§6) — the WebView modal is deleted, not repointed |
| Public share-a-lesson token links (`pvw-…`) | Keep short-term as a member-mode render with `readOnly` progress (no PreviewState), decision 08 §6 |
| Theme picker previews | Real pager page rendered in a scaled container (04 §4; native: the SwiftUI page view scaled down) |

**Retired outright:** `PreviewController.php` (3-strategy auth cascade), `preview.lesson*` +
`preview.activity` routes (`client/routes/web.php:80-176`), `PreviewToken`/`PreviewState` models
+ their action-proxy endpoints, `edit-day-pane.vue`'s `window.open('/admin/preview/…')`
(:333-334, :156-161), `ActivityPreviewPlayer.vue`, `ReadActivityPreviewModal.swift`'s preview
URL building (`EditDay.swift:1152,1254`, `ProgramHomePage.swift:1070`), and the dead
`ThemedContentView.swift`.

## 5. Migration order (feeds build-spec phasing)

1. Server: presentation fields + new enum values + streak/up-next (contract freezes here).
2. Client: the Vue member pager behind the flag — the member-facing win ships first (members
   are web-only).
3. Client: edit layer on the Vue pager; web leader panes redirect into it; preview routes 410.
4. iPhone: native pager (09) as walkthrough + edit canvas, built to match the Vue member
   experience via `/compare`; preview modal deleted; native form editors migrate
   screen-by-screen (each keeps working against unchanged CRUD endpoints meanwhile).
5. Capture: `/compare` fixtures for pager pages (native vs web twin) + editor states; retire
   preview-based fixtures.

## 6. iPhone native edit-in-place

Same principle, native implementation, arriving after the web editor (leaders keep today's
native form editors until then — they remain fully functional against unchanged endpoints):

- The native pager page views (09) are pure SwiftUI views (content + palette in, events out) —
  the editor hosts them with an edit overlay: tap-to-edit routes to the app's existing editing
  vocabulary (inline text fields, the Bible passage picker, media pickers, `ManagedMenuView`
  inspectors) via the typed Route system.
- The existing management IA (ProgramHome → EditDay → activity editors) stays — what changes is
  the activity editor's canvas: instead of a form pane + "Preview" button, the leader sees the
  real page and taps into it. Management chrome (reorder, add-activity menus, publish flow) is
  untouched.
- The old exegesis split-screen editor gives way to the floating-card page in edit mode,
  reusing `HighlightableTextView` selection + the highlighting service endpoints.

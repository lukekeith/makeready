# video-activity-basics — d2m requirements

Owner-approved changes to three existing subjects: **C-066**, **activities-editor**, **video-recorder**.
Every new input has a default; existing states, menus and callers render unchanged. No capture or
fixture may play audio. No new component: reuse C-066, C-048, C-159 DoneCheck, C-040 PageHeader, C-091.

## C-066 ActionMenuOverlay

`ActionItem` gains two fields, both defaulted:

- `enabled: Bool = true` — in the Confirmation form, false draws C-048's existing disabled look (pass
  `enabled` through to PageActionButton) and the button fires nothing.
- `subtitle: String = ""` — in the Confirmation form, a non-empty subtitle is drawn under that
  button (secondary text, small body token, centred, full card width, close to its button).

At their defaults every existing menu and confirmation is pixel-identical. New state: Confirmation with a
disabled destructive button and its subtitle (sample: "Delete video everywhere" /
"Used in 2 other lessons").

## activities-editor

Scope: the attached video page (`canvasContent: readOnly`, `readOnlyKind: video`) and the header.

1. **Still.** The page image is the existing `readOnlyPosterURL`, full-bleed, aspect-fill. No activity title
   is drawn over a video page. While `readOnlyPosterURL` is empty: the canvas background and a centred
   "Processing…" line. Other read-only kinds (youtube, write, poll) are unchanged.
2. **Player slot.** New initializer parameter `videoLayer: CALayer? = nil`, drawn over the still filling the
   page's frame, hit-testing off, same pattern as VideoDetailScreen's `playerLayer`. nil draws nothing;
   captures pass nil.
3. **Tap and hold.** A tap on the video page fires `onVideoTap`. A press held 0.5 s opens the C-066 action
   menu and fires `onVideoMenu` as it opens; no tap follows that press. VoiceOver: the page is a button that
   names the video and offers the menu as an accessibility action. This replaces §35.3's tap → Replace video menu.
4. **Hold menu.** C-066, rows in this order: "Replace" (renamed from "Replace video"; fires the existing
   `onReplaceVideo`) and "Delete" (destructive; opens the confirm and fires `onDelete`), then Done.
5. **Delete confirm.** C-066's Confirmation form, title "Delete this video?", no message, two
   destructive buttons "Remove from lesson" (fires `onRemoveFromLesson`) and "Delete video everywhere"
   (fires `onDeleteEverywhere`), and `doneLabel` "Cancel". Choosing a button closes the confirm.
   "Delete video everywhere" takes `enabled` from State `deleteEverywhereEnabled: Bool = false` and `subtitle`
   from State `deleteEverywhereNote: String = ""`. Both are read live while the confirm is open. Presentation:
   same as §35.3's menu (the screen's own ephemeral state), with a State preview seed for the open menu and
   the open confirm, so captures reach both. Cancel, the scrim and swipe close it, firing nothing.
6. **Header check.** New State `reviewSaving: Bool = false`. When true, the "Edit lesson" header's trailing
   control is C-159 (PageHeader's `showsDone`/`onDone` check) instead of the Done text, labelled "Save" for
   VoiceOver; a tap fires `onReviewSave`, not `onDone`. Back and title are unchanged. False keeps Done.
   It is shown with `canvasContent: videoRecorder`. The name means "Review offers Save"; the check is enabled.
   If C-040 cannot draw the back button, title and check together, extend its use in this screen; do not
   change C-040's other callers.

New callbacks, all defaulting to no-ops: `onVideoTap`, `onVideoMenu`, `onDelete`,
`onRemoveFromLesson`, `onDeleteEverywhere`, `onReviewSave`. `onReplaceVideo` is kept.

New states to capture: video with still; video processing (no still); hold menu open; confirm
enabled; confirm disabled with note "Used in 2 other lessons"; recorder with the header check.

## video-recorder

In `layout: fullScreen`, phase `review` only, C-159 DoneCheck at the preview's top-right, inset
`space-page-margin`, opposite the ✕ (which the app draws through `previewSlot`), labelled "Save" for
VoiceOver; a tap fires `onSave` (no-op default). `lessonInline` shows no check, and no other
phase shows it. `reviewSlot` stays the app's; it will hold Retake only. The check sits under any sheet's dim.

New state: fullScreen review with the check.

# Owner phone walk 2026-11-25 — d2m fixes (video-polish + video-activity-basics)

Subjects: screen `video-recorder`, screen `activities-editor`, C-066 ActionMenuOverlay (Confirmation form).
Every capture stays silent: 🔴 no capture, test or walk plays audio.

## video-recorder

1. **Retake becomes an icon button, top centre.** Review's text "Retake" button (now the container's
   `reviewSlot` row) becomes an icon-only button using the refresh glyph (SF Symbol
   `arrow.counterclockwise`), in the same style as the ✕. It sits **top centre**, on the same row as the ✕
   (leading) and the purple check (trailing, C-159), and is vertically centred with both. New input
   `onRetake: () -> Void = {}` (input-added-with-default); VoiceOver label "Retake". The bottom `reviewSlot`
   row is no longer needed for Review (the container will stop passing Retake there).
   In the lesson layout (`lessonInline`, no ✕ and the Save check is in the lesson header) Retake sits top
   centre of the recorder's frame, at the same top inset.
2. **Scrubber at the bottom of the video frame.** In Review the scrubber (C-151 band / review scrub) sits at
   the **bottom edge of the video frame**, inside it, not where it is now.
3. **Edit and Filters above the scrubber.** Review's Edit and Filters tools (C-147) sit directly **above the
   scrubber**, inside the bottom of the video frame.
4. **✕ aligned with the timecode.** Before recording (camera phases), the top-left ✕ moves down so its
   vertical centre matches the red C-144 TimerPill's vertical centre (TimerPill is "centred, top 20").
5. **Delete-last-clip position.** The delete-last-clip button left of the record button moves so its
   distance from the screen's leading edge equals the purple check's distance from the trailing edge —
   i.e. exactly where the photo-library (image) button sits before the first clip. Replace the current
   `deleteLastCentreX(width:) = (width/2 − 40)/2` placement with the library button's position.

## activities-editor (lesson editor's video page)

6. **Play glyph.** A semi-transparent play glyph (SF Symbol `play.fill` on a translucent dark circle,
   ~64 pt) is centred on the video page's still while the video is paused, so a tap clearly plays it. It
   hides while playing; it returns when paused or ended.
7. **Inline scrubber.** While the video plays (and while paused after playing), a scrubber runs along the
   **bottom of the video page frame**, fully visible **above the activity navigation** at the bottom of the
   screen (today nothing shows — check it is not clipped behind the activity nav). Inputs:
   `videoElapsed: TimeInterval = 0`, `videoDuration: TimeInterval = 0`, `videoScrubberVisible: Bool = false`,
   `onVideoSeek: (TimeInterval) -> Void = { _ in }`, `onVideoScrubbingChange: (Bool) -> Void = { _ in }`.
   Reuse the recorder's review scrubber component if it fits.

## Delete this video? (C-066 Confirmation, activities-editor)

8. **"Delete video everywhere" is a toggle, default off.** The confirm becomes: title "Delete this video?",
   the note (item 9), a toggle row "Delete video everywhere" (house toggle component, **off by default**),
   then one destructive button **"Delete"** and Cancel. Toggle off → Delete removes it from the lesson only;
   toggle on → Delete deletes it everywhere. When delete-everywhere is not allowed (`deleteEverywhereEnabled`
   false: used elsewhere, still loading, or the count could not be read) the toggle is disabled and off.
   Input changes: `deleteEverywhereOn: Bool = false`, `onDeleteEverywhereToggle: (Bool) -> Void = { _ in }`,
   `onDeleteConfirmed: () -> Void = {}` (the screen reports the toggle's state; the container decides
   which delete runs). The two old destructive rows go.
9. **The note moves under the title, left-aligned.** `deleteEverywhereNote` ("Couldn't check where it's
   used", "This video is used in N lessons", …) moves from under the button to **directly under the
   "Delete this video?" title**, left-aligned (body-sm, text-secondary). The subtitle-under-button support
   added to C-066's Confirmation can go if nothing else uses it.

## Not for d2m (app code, done separately)
- The upside-down video and still: an export fix in `VideoExporter` (orientation drawn into the pixels).

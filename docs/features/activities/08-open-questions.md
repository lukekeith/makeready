# 08 — Open Questions (decide before /build-spec-draft)

1. **READ migration depth.** Day one renders legacy `READ` as derived TEXT/BIBLE pages (03 §4.1).
   Do we ever backfill-convert `READ` rows + `ActivityReadBlock`s into real TEXT/BIBLE activities
   (one-time script, updates content hashes → sync implications for enrolled schedules), or keep
   the derived rendering forever? Recommend: derive for launch, convert in a follow-up once the
   pager is default.

2. **Fate of the animation themes** (star-wars, typewriter, bold-slide, dramatic-reveal,
   gentle-fade). `revealMode: WORDS` + motion presets cover the tasteful subset. Kill the rest,
   or keep a legacy player route for existing published content that uses them? (Usage query
   needed: how many published activities reference each theme slug.)

3. **Streak definition.** Consecutive *scheduled* lessons completed by their scheduled date
   (strict), or consecutive completions with ≤N-day gaps (forgiving)? Does the streak span
   enrollments in the same program, or is it per-enrollment? Timezone source = enrollment
   `timezone`? (The reference shows a simple integer with a droplet icon.)

4. **Narration.** Video 1 is narrated (mute chrome) with narration-paced word cues. Is authored
   audio narration in scope for v1 (audio upload per lesson/page + word-timestamp generation),
   or does `WORDS` reveal ship with the fixed-cadence fallback only? Recommend: fallback only in
   v1; cues are additive later (`narrationCues` field already sketched).

5. **Prayer list backend.** `ADD_TO_PRAYER_LIST` needs a destination: new note type `PRAYER` in
   the existing notes pipeline (member-scoped, private-by-default) vs a dedicated `PrayerListItem`
   model. Where does the member later see the list (web member area exists; iPhone member surface
   is the web app)? The reference's privacy footer implies future sharing — model that now or not?

6. **Share/preview links.** Public `pvw-` links die (07). Do org leaders still need a
   "share this lesson with someone outside the group" link? If yes: member-mode render with
   read-only progress, no synthetic state. If no: delete outright.

7. **Autoplay + audio policy in plain Safari (web player only).** The native player autoplays
   with sound freely; mobile Safari cannot. Accept muted-autoplay + tap-to-unmute chip on
   VIDEO/YOUTUBE pages in the browser, or require the entry tap to double as the audio gesture
   (playsinline + unmute on first interaction)? Affects how faithful the video-1 "narration
   starts immediately" feel is on the web twin.

8. **Feature flag scope.** `lessonExperience: pager|legacy` per enrollment (recommended: org →
   enrollment override) and the sunset criteria for deleting the legacy step player.

9. **Indicator on very long lessons.** Dot rail with >10 activities: cap visible dots with
   ellipsis-fade (reference lessons are 6-7 pages), or scale dot spacing? Pick at design time.

10. **Exegesis completion rule default.** Today completion requires visiting every highlight.
    With dozens of highlights (the redesign's explicit goal), is `AFTER_HIGHLIGHTS` still a sane
    default, or should EXEGESIS default to `FREE` with per-activity opt-in strictness?

11. **YouTube in the native walkthrough.** YouTube's ToS requires the IFrame player, so showing
    a YOUTUBE page in the native pager needs a scoped WKWebView island for the video surface
    (09 §5) — acceptable exception to the no-WebView rule, or does the native walkthrough render
    a thumbnail/poster placeholder for YOUTUBE pages (playable only on web)?

12. ~~Member access to the iPhone app.~~ **DECIDED 2026-08-09: members will not access their
    content from the iPhone app, not anytime soon.** The Vue pager is the only member runtime;
    the native pager (09) is the leader's edit canvas + walkthrough and writes no member
    progress.

13. **Custom serif on native vs web.** The SCRIPTURE role needs the same face on both platforms
    (bundled font on iOS + licensed webfont) or platform defaults (New York / system serif
    stack) with accepted visual divergence. Licensing decision before the palette tokens freeze.

14. **WRITE submission content shape (rich text).** The Notes-style input surface
    (11-notes-editor-analysis.md §7) gives members bold/italic/underline/strikethrough and
    lists, but `POST …/submit { note }` and the SOAP notes pipeline store a plain string.
    Options: (a) keep plain text for members and drop the format strip's styling toggles from
    the member player (Notes canvas feel only), (b) store markdown (loses underline unless an
    extension is accepted) reusing the TEXT activity's block format, (c) new rich-note content
    type in the notes pipeline. Affects server contract, both players, and any place existing
    notes render (leader review surfaces).

# video-activity — program
> tier: program · no ticket · follow-on to video-polish (owner phone walk 2026-11-24)

## Overview

A video activity in the lesson editor should behave like a real video. Today its page shows the
auto-name ("Video 1") on a blank canvas, a tap opens a one-row "Replace video" menu, a saved video
can never be edited again, Review's Save is a text button, and video slides on the group and
enrollment rails are blank. This program makes the video page show its picture and play on a tap,
puts Replace · Edit · Delete behind a hold, lets Delete choose its scope, moves Save to the header's
purple check, and lets a leader add text over a saved video as a new version.

It is cut into two children, each usable on its own. **video-activity-basics** ships everything but
re-editing a saved video. **video-activity-edit** adds Edit, which needs a new server endpoint for a
downloadable copy and the re-edit flow. The web client is unchanged: it plays whatever video the
activity links.

Brainstorm record: `.builder/video-activity/brainstorm.md` — 10 settled by the owner, 3 assumed.

## Children

| # | Feature (folder) | Size | Apps | One line | Depends on |
|---|---|---|---|---|---|
| 1 | video-activity-basics | lg | server+iphone | A leader sees a video activity's picture in the editor and on every rail, taps to play it, holds for Replace · Delete (choosing to remove the activity or also delete the video), and saves a recording with the header's purple check | — |
| 2 | video-activity-edit | lg | server+iphone | A leader holds a saved video activity, picks Edit, adds text over the saved video, and saves it as a new version that this activity now plays | 1 |

Order: basics first — it builds the hold menu that Edit joins, and it carries no contract edit needs.
edit then adds the download contract (server first, then iphone).

## Shared decisions

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| P1 | Video page preview | The lesson editor's video page shows the video's Cloudflare thumbnail (`media[videoId].posterUrl`, fetched into the image cache); no activity title is drawn over it. Rejected: the title over a blank canvas | Luke 2026-11-24 |
| P2 | Tap and hold | On the lesson editor's video page a tap plays/pauses the video inline; a tap-and-hold opens the house C-066 menu: Replace (renamed from "Replace video") · Edit (child 2) · Delete. Rejected: a tap that opens a one-row menu | Luke 2026-11-24 |
| P3 | Where the hold menu lives | The lesson editor's video page only; the program home keeps its current slide menu. Rejected: both places (two menus to keep matched) | Luke 2026-11-25 |
| P4 | Delete | The confirm offers both scopes: "Remove from lesson" (the activity only; the video stays in the library) and "Delete video everywhere" (the activity and the library video), plus Cancel. Rejected: a fixed scope | Luke 2026-11-24 |
| P5 | Save on Review | Review's Save is the purple check (C-159 DoneCheck) in the header in both layouts: in a lesson the "Edit lesson" header's trailing Done becomes the check while Review is up and saves the video; full screen shows the check top-right opposite the ✕. Retake stays on the bottom row. Rejected: full screen only | Luke 2026-11-24 |
| P6 | Server lesson thumbnail | `next-study-thumbnail` falls back to the video's Cloudflare still when an activity has no poster, so video slides show on group and enrollment rails. Rejected: iPhone only | Luke 2026-11-24 |
| P7 | Edit on a saved video | Opens the video editor on a downloaded copy of the saved video; text and captions are added over it; Save uploads a new version that replaces this activity's video. Burned-in text can't change. Rejected: edit title/details only; Edit only before saving | Luke 2026-11-24 |
| P8 | The original after Edit | Stays in the library; only this activity switches to the new version. Rejected: replace everywhere (deletes the original, changes other lessons) | Luke 2026-11-25 |
| P9 | Inline playback | Starts paused on the thumbnail; sound on; stops at the end; a tap at the end replays — as Review (video-polish D9) | (assumed at brainstorm) 2026-11-24 |
| P10 | Apps | server + iphone; the web client is unchanged | (assumed at brainstorm) 2026-11-24 |
| P11 | Walks never play audio | No agent walk, test or capture plays sound; inline playback and Edit are walked muted or owed to the owner's phone (`.claude/builder.md` §Standing traps) | owner 2026-11-24 |

## Out of scope

- Changing text already drawn into a video.
- The hold menu on the program home's slides.
- Any web client change.

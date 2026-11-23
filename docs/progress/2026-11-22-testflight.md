This build adds two new ways to capture thoughts: written Notes and Voice Memos. Both live in a new Library tab, which now has search, filters and swipe-to-delete. Notes and memos save on the device first and sync when you're online, so please try them with a weak or no connection too.

**Notes**
You can write formatted notes (bold, lists and so on) with a format bar above the keyboard. Notes save automatically as you type.
How to test:
1. Tap + > Write a note, or use the compose bar in Library.
2. Type, apply bold and a list, then leave the note.
Expected: the note appears in Library with its first line as the preview. Reopening it shows the same formatting. An empty note you leave is discarded. Undo sits beside the format bar. The purple checkmark at the top right closes the keyboard. The bar keeps a small gap above the keyboard.

**Voice memos: recording**
Tapping + > Voice memo opens a recorder panel. It waits for you to press the red button before it records.
How to test: open the recorder, wait, then tap the red button. Record about 15 seconds, then pause, resume and tap Done.
Expected: the panel slides up smoothly with all of its contents and dims the screen behind it. Nothing records until you tap the red button. The waveform scrolls smoothly while recording. When you finish, the memo's page opens. Tapping the dimmed area or swiping down before recording closes the panel without saving. Doing either while recording saves the memo, so it's never lost. Discard asks you to confirm first.
Also check: deny microphone access in Settings. The panel should explain the problem and offer a button to open Settings.

**Voice memos: memo page and transcript**
Each memo has its own page with playback, a waveform with a moving playhead, and a transcript made on the device.
How to test: open a memo from Library, play it, scrub it, and rename it from its page.
Expected: playback is smooth and the playhead follows the audio. The transcript appears within a short time; it shouldn't stay on "Transcribing...". A memo recorded offline shows up right away and uploads once you're back online. Renaming it before the upload finishes still sticks.

**Library**
Notes and memos now appear together in one list. Each row has an icon in a circle, and the memo time is shown in purple.
How to test: search by a word, filter by Type (you can pick Notes, Memos or both), and pull to refresh.
Expected: results update as you type, and the filters work together.

**Swipe to delete**
How to test:
1. Swipe a Library row partway to the left and let go. A red delete circle stays visible; tapping it asks you to confirm.
2. Swipe all the way to the left until you feel a tap, then let go.
Expected: the row folds away in place and the rows below slide up. It should not slide back or bounce.

**Also**
- The back, menu and Done buttons at the top of the detail pages are larger and match the rest of the app.
- Opening "Write a note" from Library now slides cleanly, with no shrinking or jump.
- The Home charts now fit narrower iPhones.

Please focus testing on recording a memo and opening the memo afterwards, offline notes and memos syncing later, swipe-to-delete in Library, and typing in the note editor with the keyboard open.

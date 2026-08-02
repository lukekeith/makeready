This build focuses on the study content editors and the enrollment day editor. Exegesis highlighting gets its biggest fix — overlapping highlights now merge into one — alongside a batch of editor quality fixes: the formatting toolbar stays above the keyboard, Preview always shows your latest text, and the enrollment day editor's YouTube and Exegesis rows now open real editors. Program deletion is also tightened so leaders can only delete studies they created.

**Merging exegesis highlights**
Highlighting text that overlaps an existing highlight now merges the two into one continuous highlight instead of failing to save. If both had notes, the merged highlight keeps both.
How to test: Open a study → Exegesis activity → highlight a few verses, then select a range that partially overlaps that highlight. You should see a single highlight spanning both ranges. Close and reopen the editor — the merged highlight persists. Tap it to confirm any notes from both originals are present.

**Enrollment day editor: YouTube & Exegesis**
Tapping a YouTube or Exegesis activity inside a group enrollment's day now opens a fully working editor (these previously failed to open).
How to test: Group → enrollment → open a day → tap a YouTube activity, then an Exegesis one. Both should open their editors and save changes normally.

**Enrollment day editor: instant updates**
Newly added or reordered activities now appear immediately, and the "+" button schedules the study's next unscheduled lesson.
How to test: In a day editor, add an activity and drag one to reorder — the list should update on the spot, no need to back out and reopen. Then tap "+" on the enrollment: the next lesson from the study appears (not a duplicate or an empty day).

**READ editor: Preview shows unsaved text**
Preview now includes what you just typed, even before saving.
How to test: In a READ activity, type new text and immediately tap Preview — the new text is there.

**Formatting toolbar above the keyboard**
The editor's heading/formatting toolbar is pinned directly above the keyboard instead of hiding behind it.
How to test: Focus any text block in the content editor — the toolbar should sit on top of the keyboard and stay there while typing.

**Exegesis preview after backgrounding**
Backgrounding the app while viewing an exegesis preview no longer breaks the layout on return.
How to test: Open an exegesis lesson preview, switch to another app, come back — the preview should render correctly.

**Program deletion is creator-only**
Leaders can no longer delete studies someone else created — deleting is reserved for the study's creator (editing shared org studies is unchanged).
How to test: As a leader who didn't create a study, try to delete it — it should refuse and the study stays. The creator can still delete it.

**Also:** the tag field keeps the keyboard open after adding a tag so you can type the next one straight away, and the empty cover-image well now reads "Tap to select cover image."

Please focus testing on: exegesis highlighting (merge, notes, persistence), the enrollment day editor (opening YouTube/Exegesis editors, add/reorder), and READ editor preview + toolbar behavior.

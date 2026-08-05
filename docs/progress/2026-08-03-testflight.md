This build works off the bug list filed against the last TestFlight build, so most of it is fixes to things you reported. The study content editors got the most attention: Read-activity highlighting no longer strands those mystery selection handles, and exegesis notes moved to a proper full-screen editor. Program Home also gains a new Analytics tab — that one needs the server update deployed before it will show anything.

**Read activity: highlighting**
Tapping the highlighter on a Bible verse block used to leave two floating selection handles with nothing between them. The selection is now painted directly on the verses and those handles are gone. Highlight mode also no longer traps you — Cancel and Done were greyed out and unresponsive, so an activity with a single verse block could only be escaped by force-quitting.
How to test: Open a study → a Read activity with a Bible verse block → tap the highlighter icon at the block's top right. You should see the hint "Tap verses to select, then tap again to style". Tap a verse — it fills with a yellow-green wash that stays put while you tap other verses or type elsewhere, and no lollipop-shaped drag handles appear at any point. Tap a selected verse again to open the style picker. Then tap Cancel, Done or the empty background: you should leave highlight mode with nothing saved or discarded, and a second tap does the button's normal job.

**Exegesis: full-screen note editor**
The note editor was a bottom sheet that resized itself around the keyboard, so the field shifted under you as you typed. It is now a fixed full-screen editor with the quoted passage above the note and dots to move between highlights. Separately, a highlight that already had a note still offered only "Add note", and the saved note could not be reached.
How to test: Exegesis activity → tap a highlight → Add note. Type past the bottom of the field — nothing under your cursor should move or resize. Swipe left/right (or tap the dots) between highlights; unsaved text should survive the trip. Tapping the background should NOT close the editor. Save, leave the activity, reopen it and tap that highlight — the button should now read "Edit note" and open with your text in it.

**New Analytics tab**
Studies now have an Analytics tab beside Lessons and Enrollments, with headline numbers, top groups, recent activity and a heatmap, plus a Week/Month/Year toggle.
How to test: Open a study with real enrollments → Analytics. Numbers should populate and the toggle should redraw the charts. A brand-new study should show a tidy empty state, not a blank tab. If the whole tab fails to load, check that the server update has been deployed before logging it.

**Enrollment scheduling**
When every lesson in a study is already scheduled, the "+" button is now disabled up front and explains why, rather than letting you tap it and then showing a red error.
How to test: Open an enrollment where all lessons are scheduled — the add row should be disabled and read "Every lesson in this study is scheduled", with no red bar.

**Bible reader verse numbers**
How to test: Open the Bible reader and swipe back and forth through several chapters — the gutter verse numbers should be there every time, with none left over from the previous chapter.

**Also:** tags, members, enrollments, posts and join requests now share one source of data, so screens stay in step — a tag you add to a study appears in the Library tag filter straight away, and approving a join request updates the list and its count everywhere at once. Lesson previews that fail to load now say so instead of opening blank.

Please focus testing on: Read-activity highlighting, the exegesis note editor, the new Analytics tab, and cross-screen freshness after adding tags or approving join requests.

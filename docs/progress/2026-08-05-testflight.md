This build is almost entirely about **text highlighting**. The Exegesis editor, the Read activity editor and the Bible reader each used to have their own highlighting code, and they disagreed with each other — on how much text you select, what colour it paints, and when a selection actually saves. They now share one engine. Highlights are also stored properly on the server instead of being buried in the lesson content, and existing highlights were migrated across. Please test highlighting broadly, not only the specific steps below.

**Highlights save when you let go — never on a timer**
A highlight could previously be created while you were still dragging.
How to test: In an Exegesis activity, press and hold on a verse and drag to extend the selection. Keep holding for several seconds and drag back and forth. Nothing should save until you lift your finger, and only the final span should stick.

**Selection snaps to whole words**
You can no longer end up with half a word highlighted.
How to test: Start a drag in the middle of one word and release in the middle of another — the saved highlight should grow outward to cover both words fully. Also try a word with an apostrophe, like "Lord's": it must stay whole, not split.

**Notes survive when highlights merge** ← most important
Drawing a highlight across existing ones combines them into one. Notes used to be lost doing this.
How to test: Add two highlights on the same passage and give each a different note. Then highlight across both. The single resulting highlight must contain **both** notes. Nothing may go missing.

**No page jump on the second highlight**
How to test: Make a highlight, scroll elsewhere, then make another. The page must not snap back to the first one's position.

**Re-highlighting deleted text works**
It used to fail silently, forever.
How to test: Highlight a phrase, delete the highlight, then highlight the same phrase again. It must work the second time.

**Read editor: press-and-hold word selection (deliberate change)**
Tapping a whole verse no longer selects it. You press and hold to select words, like the Exegesis editor — so you can now highlight part of a verse, which wasn't possible before.
How to test: Press and hold in a Read activity's passage and drag. You should get a word-accurate highlight. A single tap should only reopen an existing highlight, not create one. Watch closely for any page jump or stutter while dragging — this screen has scroll-locking for the first time.

**Highlight colour is now yellow-green instead of purple**
How to test: Open activities that already had highlights. Confirm they all still appear, in the right place, in the new colour — and that none have vanished.

**Verse cards keep their rounded corners**
How to test: Highlight inside a Bible verse card; the card corners should stay rounded.

**Highlights are stored server-side and survive restarts**
How to test: Add a highlight, force-quit the app, relaunch and reopen the activity. It should still be there with its note. On a Read activity with several passage blocks, highlight in more than one block and confirm each stays on its own block.

**Also:** enrolled groups' lesson schedules should look completely normal — nothing re-synced or reset.

Please focus testing on **the Exegesis editor's merge-with-notes behaviour**, **the Read activity editor's new press-and-hold selection**, and **the Bible reader** (it shares the new engine but should behave exactly as before — it's had the least exercise). If you're on an older build that you haven't updated, please also confirm your existing Read highlights still show up.

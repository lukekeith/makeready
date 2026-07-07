# Monday.com — Incomplete Ticket Inventory (raw)

Pulled 2026-07-05 from the **App** workspace. This is the raw, per-ticket record (item name, description, and every update/comment). Analysis, prioritization, and work plan live in [README.md](README.md).

Boards:

- **Ongoing Tasks Tracking** (`18413909869`) — bugs & feedback. 22 items not marked Done.
- **Feature requests** (`18417603408`) — 12 items (board has no status column; all treated as open).

Reporter on nearly all items is Scott Stickane, testing as a group leader (iPhone app) and as a member (mobile web browser). Most items have no description field — the substance is in the updates, transcribed below. Screenshot attachments exist on most updates (not copied here; see the item URL).

---

## Ongoing Tasks Tracking — open items

### 12081607589 — Confused with the notes in the group
- **Priority column:** Low · Created 2026-05-22
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12081607589
- **Description:** "Unsure about the notes on the group page. If the activity posted is because the group started a new study, let's make a badge or status bar to show the group is enrolled in the study and it's active."

### 12101572041 — Inspirational notes
- Created 2026-05-25
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12101572041
- **Description:** "I am in Hawaii. I have had an inspiration — the only way I can get it out is to add it to a random study. I want something better. Maybe notes? Maybe a new lesson without being connected to a study? I want the ability to create a note based on my inspiration and then easily be able to add it into a lesson."

### 12268645785 — validation error
- Created 2026-06-13
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12268645785
- **Updates:**
  - (Jun 13) "I get this error by clicking on a lesson in the study enrollments and then 'open lesson' — then I get a prompt to authenticate with phone number." Repro path (reply): *groups / enrolled / study + group / open lesson / continue / validation*.
  - (Jun 20) "Did a bunch of work here and now the changes won't save."
  - (Jun 23) "Still getting an error here working through the web browser as a user when trying to join a study using my phone number."

### 12268464531 — publishing toggle error
- Created 2026-06-13
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12268464531
- **Updates:**
  - "If I publish a study and then enroll a group, I can unpublish it without an error or warning. Unpublishing doesn't change the enrollment status. It should kick all enrolled groups out."
  - "I believe this saying 'incomplete' is a residual error from unpublishing and republishing. As a user I can't fix this."
  - "There is a disconnect between the lessons in the study and the lessons the group can see once the study is published and unpublished, edited, then republished."

### 12268648378 — no way to change enrollment calendar
- Created 2026-06-13
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12268648378
- **Update:** "I want to change the days and time and frequency of the study but can't."

### 12268465402 — should say lessons
- Created 2026-06-13
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12268465402
- **Update:** "This says 'studies' but should probably say 'lessons'??"

### 12268478769 — add bible verse unclear
- Created 2026-06-13
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12268478769
- **Update:** "I am unsure every time how to add a bible verse here. The + only does one thing. Let's make it obvious. Or start without the custom text field up."

### 12268576962 — calendar breaks when unpublishing
- Created 2026-06-13
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12268576962
- **Update:** "Once the study is published and enrolled, I can unpublish and re-enroll and then add days and they don't show up on the study for the member."

### 12268578241 — covering text
- Created 2026-06-13
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12268578241
- **Update:** "I can't see the text because of the button. You mentioned you fixed this, but this is an old study and I think it's a holdover error."

### 12270302158 — rescheduling
- Created 2026-06-13
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12270302158
- **Updates:**
  - "I can't ever get back to this screen to republish."
  - "This screen I want to get back to also to republish or change the enrollment."

### 12271625826 — image optimize
- Created 2026-06-14
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12271625826
- **Update:** "Question — I'm feeding this app full-res images. What is the size of them on the server? Are they optimized?"

### 12297336134 — stuck
- Created 2026-06-17
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12297336134
- **Updates:**
  - "Read lesson. Highlighted. Now stuck."
  - "I'm looking for a button to complete my input. I get stuck here until I accidentally swiped down on the keyboard."
  - "As a member the study is totally empty. I caused this error by rearranging the lessons in the study and then enrolling. There should be content."
  - "As a user I have moved to a different app and the URL bar is covering the nav text. I don't know what to do now. The button at the top takes me to the next section."
  - "It is impossible for me to create a read lesson and then go back to the top of custom text I've added, select it, and change the heading type. The UI scrolls down to the point where I can't get to the H1/H2/H3 heading selection."

### 12297338039 — error log
- Created 2026-06-17
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12297338039
- **Updates:**
  - "I can't seem to highlight the last verse of the exegesis — error."
  - "I didn't insert this text. It's like it's saving it every second and saving to search memory." (phantom text in read editor)
  - "If I create a study, add a read lesson, and make the read title incredibly long, I get an error and can't save it."
  - "I'm trying to select text on a read lesson by tapping and holding. I expect the cursor like a typical iOS app; instead I have to double-tap. Very difficult to select text on a read or exegesis lesson."
  - "This is from groups > enrolled > swipe left > trash. Error. It doesn't unenroll."
  - "After successful transfer the screen gets stuck. Restart needed."

### 12297345805 — suggestion
- Created 2026-06-17
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12297345805
- **Update:** "We don't need a 'read (bible)' and an 'exegesis'. Should combine. Exegesis should be renamed 'add bible verse'. 'Read' should be 'custom text'."

### 12325580210 — UX change needed
- Created 2026-06-20
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12325580210
- **Updates:**
  - "Exegesis highlighting is clunky. Very difficult to select what you want, then impossible to edit the highlight after it's selected."
  - (Jul 5) **"I can delete studies that aren't mine."** ← buried in this ticket; treated as its own issue in the analysis.

### 12344861586 — UX update please
- Created 2026-06-23
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12344861586
- **Updates:**
  - **"I can enroll my group in someone else's study. This shouldn't be possible."** The GL should have to make the study their own / get permission / creator marks it for org consumption.
  - "I can't unenroll a group from a study."
  - "'Open lesson' here doesn't make sense — it makes me validate as a member and throws a validation error. This is a fancy way to preview."
  - "I have written my notes as a member and now I don't know how to get out of the study."
  - "Member — I think people will get stuck here without a next or save button."
  - "It is nearly impossible for me to select what I want." (member text selection)
  - "These don't work. Also unconvinced about this bar in general — should go away for v1." (rich-text toolbar buttons)
  - "Get rid of the text edit bar."
  - "I made a long note, then selected over top of it with another highlight and it deleted my other note. I can't get it back." (data loss)
  - "I'm writing a note and the keyboard is covering what I am trying to edit."
  - "I have no way to edit my existing note, or even read it again."

### 12344966853 — UI update please
- Created 2026-06-23
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12344966853
- **Updates:**
  - "This icon is incorrect — makes me feel like there was an error in the unenrollment."
  - "Not sure we need the birthday — maybe just birth year. Also there's no minimum-age requirement; should be based on the group age range, otherwise remove the age range."
  - "The blue color here isn't right. I'd like this to look like a piece of paper — white pages, black text; highlights yellow/blue/pink. On black the serif font looks like an error."
  - "I feel like this should be vertically centered."
  - "The themes for reading are too much for v1."
  - "I can't get to the bottom-most story easily — always half covered by the UI."

### 12344966891 — UI not updating
- Created 2026-06-23
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12344966891
- **Updates:**
  - "I have unenrolled my group but it still shows up. This has been an issue previously — items still remaining after a change is made."
  - "This is the error I get when I select the group enrollment I previously deleted."

### 12386101354 — error member experience
- Created 2026-06-27
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12386101354
- **Updates:**
  - "Empty lessons." (screenshot)
  - "Navigation covering the verse."

### 12415667946 — member - video
- Created 2026-07-01
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12415667946
- **Update:** "The UI doesn't scroll here. Once I watch the video there is a strange message (see screenshot). It's unclear how to get to the next section. The top nav is hidden."

### 12415662995 — member - reading issue
- Created 2026-07-01
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12415662995
- **Update:** "I can't see the top of the bible verse (exegesis) or the address of the bible. I think the top nav is too big and it often gets in the way."

### 12415690223 — member - error
- Created 2026-07-01
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12415690223
- **Update:** "This is a study that was unenrolled, then edited, enrolled, and deleted — I can't make this go away from my member UI or the GL UI."

### 12081585156 — (older item, still receiving updates)
- **URL:** https://scotts-team283817.monday.com/boards/18413909869/pulses/12081585156
- Marked verified-fixed on Jun 11 (header overlap), but Scott has since added:
  - (Jun 17) "I don't know if this is only in preview or not but it doesn't work."
  - (Jun 23) "I can't read it. There's too many navigation elements here."
  - (Jun 27) "I can't even get to the text as a member — no idea what it says and can't move it."

---

## Feature requests — all open

### 12266593869 — Solicitation of lesson in study
Guest lesson contribution by link: send friends a private link (no app download) to author lesson activities for a study; track guest author; creator sets lesson count and gives direction; accept/reject flow; guest content auto-inserted marked "for review". (v2: notes back to guest.)

### 12268474877 — Lesson library / migration
Move lessons between studies; duplicate a lesson; move AND copy a lesson without destroying study flow; build a study by choosing lessons from a lesson library.

### 12268463248 — Study template creator
Create custom lesson templates; by default a custom template applies only to that study.

### 12268427023 — Duplicate study
Duplicate a study to "dumb it down or dress it up" for a different audience.

### 12270300418 — Adding content to a published study
Add content/lessons to an already published + enrolled study; new lesson auto-added to the calendar; missed/missing dates don't stop the study; lesson frequency preserved.

### 12354285433 — Ability to add content to a published study *(duplicate of 12270300418)*
"Open"/living studies so people can be added mid-study and content can be added after publish.

### 12270300519 — Skipping or adding a special lesson
Insert a special lesson (current events, special date) into an enrolled study; skip a lesson or change the schedule at any time; a skipped lesson can be rescheduled or removed.

### 12303207603 — Add makeready videos to lesson
Add one of ~400 MakeReady social videos into a lesson; architecture must extend to org private content libraries.

### 12273864192 — Add makeready videos to lesson *(duplicate of 12303207603)*
Same, plus: find videos via tag search or transcript (words spoken) search.

### 12303257933 — User management
Remove people from a group.

### 12303272591 — User notes compiled by AI
Members get an AI summary of how they've changed based on their notes; members can read their old notes; summary auto-created at the end of each study or chapter.

### 12303188320 — Lesson chapters
Create a lesson chapter as part of a study; chapters trigger the AI notes summary.

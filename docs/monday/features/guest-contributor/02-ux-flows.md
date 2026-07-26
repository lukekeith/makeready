# Guest Contributor — UX Flows

← [README](README.md) · [Architecture](01-architecture.md) · [Delivery plan](03-delivery-plan.md)

Three people touch this feature: the **leader** (issues invites, reviews), the **contributor** (authors on the web), and the **member** (sees the finished lesson). This document walks each flow, the screens involved, and the empty/error states. It's written so UI work can begin from it once the architecture is signed off.

Where an existing surface is reused, it's named with its file so the build starts from real code, not a blank canvas.

---

## Flow A — Leader issues an invite

**Entry point:** Program Home (the study container — web `/admin` LeaderApp, already built: `manifest.md:83`; iPhone `ProgramHomePage`). Add an **"Invite contributor"** action to the study's managed menu / "+" menu (the same menu family as `libraryAddMenu` / AddMenu).

**Screen: Invite contributor (overlay form).** Fields:
1. **Who** — invitee **email** (required; this is the email-lock target, D2).
2. **What to contribute** — a segmented choice (D1):
   - **A whole lesson** → lesson picker (existing lessons in this study).
   - **A specific activity** → lesson picker → activity picker within it.
   - **Write new lessons** → a **count** stepper ("Ask them to write ___ lessons").
3. **Direction** — a free-text **"What's this study about / what should they write?"** box (`topicDirection`). Optional but encouraged; shown to the contributor throughout.
4. **Expiry** — optional ("link expires in 14 days").

**On submit:** creates the `ContributionInvite` + magic link. Leader gets a **shareable-once link** they can copy, plus an optional "email it for me" (server sends the link to `invite.email`). Copy explicitly states: *"This link only works for {email} — it can't be used by anyone else."*

**Tracking:** the study gains a small **"Contributors"** section listing outstanding invites and their status — `Pending` / `Claimed` / `Submitted` / `Approved` / `Rejected` — each with **Revoke** and **Resend**. This is where the leader later finds the review queue (Flow C).

**States:** invalid email; picking an activity in a lesson that has none yet; count = 0; re-inviting the same email (offer to resend the existing invite rather than duplicate).

---

## Flow B — Contributor authors on the web

This is the flagship experience and the reason web video recording exists. **No app download; web only.**

### B1 — Open the link & sign in
- The magic link opens a branded **landing page**: "{Leader name} invited you to contribute to {study name}." Shows the **topic direction** and exactly what's being asked ("Write 2 lessons" / "Edit the lesson 'Grace'"). One primary button: **Sign in with Google**.
- OAuth runs redemption-aware (§1). **Email-lock:** if the person signs in with a Google account whose email ≠ the invite's, they hit a clear **"This invite is for {masked email} — sign in with that account"** screen, not a generic error.
- First-time contributors are provisioned silently (no org, no role); returning contributors land straight in.

### B2 — The scoped editor shell
The contributor sees a **stripped-down surface** — the existing overlay editors, hosted **without** the leader nav, Library, Groups, Enrollments, or whole-study loaders (§2). Layout:
- **A slim header:** study name + "Contributor" badge; no tab bar.
- **An assignment panel:** the leader's **topic direction** pinned + a checklist of what to produce ("Lesson 1 of 2", "Lesson 2 of 2", or "Activity: Video").
- **The editor(s):** only the assigned target.
  - *Whole-lesson / write-new-lessons:* the **EditDay** lesson editor (`manifest.md:85`) with the activity editors (write / read / youtube / exegesis — all already wired, `manifest.md:87-90`) and an **add-activity** menu. For "write N lessons," each new lesson is created via the quota-checked `POST /programs/:id/lessons`.
  - *Single activity:* opens **directly into that one activity editor**, nothing else visible.
- **Video activity → in-browser recording** (see B3).
- Everything writes through the **same server APIs** the iPhone/leader use (`leader-program.store.ts` verbs), now authorized by the contributor's grant.

**What they cannot see or do (by construction):** other lessons, other studies, the media library, group/member data, publish, export. Any out-of-scope navigation simply doesn't exist in this shell, and the API denies it anyway (S4).

### B3 — Recording a video (the new capability)
Inside a video activity, the contributor gets a **`<VideoCapture>`** panel (§6):
1. **Record here** — permission prompt → live camera preview → **Record / Stop** → playback → **Use this / Re-record**.
2. **Or upload a file** — file picker; on a phone browser this opens the native camera (`capture="user"`).
3. On confirm: upload to Cloudflare (progress bar; resumable) → **"Processing…"** while transcoding → thumbnail appears → attached to the activity.

**States:** camera/mic denied (explain how to re-enable, offer file upload); unsupported browser MediaRecorder (auto-fall back to file upload); long upload on weak network (resumable, "keep this tab open"); processing failure (retry).

### B4 — Submit for review
- A persistent **"Submit for review"** button, enabled once the required items exist (e.g., all N lessons have content). Submitting moves the `Contribution` to `SUBMITTED` and shows a **"Sent to {leader} for review"** confirmation.
- The contributor can **return via the same link** to revise **until** it's approved (grant stays `ACTIVE`). After approval or revoke, the link shows a friendly **"This contribution is complete / no longer available"** state.

---

## Flow C — Leader reviews

**Entry:** the study's **Contributors** section (Flow A) → **Review** on a `Submitted` item. Also a **notification** ("{name} submitted their lesson") via the in-app `Notification` feed (`schema.prisma:1636`) and/or APNs to the leader's iPhone.

**Screen: Review a contribution.**
- A **read-only preview** of exactly what the contributor produced — rendered with the real lesson/activity renderers so the leader sees what a member would see (video plays, read blocks render).
- **Attribution** shown: "Guest author: {name}".
- Two actions: **Accept** and **Reject**.
  - **Accept** → `Contribution.status = APPROVED`, clearing the quarantine gate. The content becomes eligible for the next publish; if the study is already live, it flows through the normal sync ("auto-added to the calendar," FR-1). Leader gets an optional "Publish updates now?" nudge if the study is live.
  - **Reject** → `Contribution.status = REJECTED`; content stays quarantined (never reaches members). **v1:** a simple reject. **v2 (D4):** attach `feedbackNotes`, return the contribution to the contributor as `DRAFT`, and re-open their link for a revise-and-resubmit cycle.

**States:** nothing to review (empty queue); contribution submitted then the contributor kept editing (lock editing on submit, or show "resubmitted" — v1 locks on submit); leader rejects then wants to salvage part (v1: leader can edit the content directly after accept, since post-accept it's normal study content they own).

---

## Flow D — Member sees the lesson

Members are unaffected until a contribution is **approved and published/synced** — then the lesson appears in their study exactly like any other (existing lesson player; no member-side changes). 

**One product decision (open):** whether to **display the guest author's name to members** ("Guest teacher: {name}") or keep attribution leader-facing only. The data supports both; default proposed: **show it** (the ticket says "display it with the lesson"), togglable per invite. See [03 § Open questions](03-delivery-plan.md#open-questions--risks).

---

## Surface reuse map (so UI work starts from real code)

| New UI | Reuses / hosts |
|--------|----------------|
| Invite contributor form | LeaderApp overlay/menu system (AddMenu / managed-menu family); email + pickers |
| Contributors / review section | New section on Program Home; list + status chips |
| Contributor landing + email-lock screens | New minimal branded pages (Laravel/Blade + a small Vue island, or the leader-app island shell) |
| Scoped editor shell | The existing overlay editors (`EditDay`, write/read/youtube/exegesis) hosted without leader nav/whole-study loaders |
| `<VideoCapture>` | **New shared component**, used by both the contributor shell and the leader app (parity gap closed) |
| Review preview | The real lesson/activity **renderers** in read-only mode |
| Member view | **Unchanged** existing lesson player |

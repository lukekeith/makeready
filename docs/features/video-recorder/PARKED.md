# video-recorder — parked
parked: 2026-11-23 463f78aa · by build phase 1 (fleet unpark retry 1 of 2)
kind: human-step
blocked: "d2m requests can't create the new Video Recorder and Video Detail screens, and the owner approves every d2m screen before iPhone code (P2) — next: create both in the d2m app (see PARKED.md), approve the screens, then /builder:agent"

## What is stuck
Phase 1 needs d2m to spec and build two NEW screens, `video-detail` and `video-recorder`, then the
owner to approve every d2m screen in this feature before any iPhone code (SPEC §iphone: "Phase 1 is
d2m (P2): no app code until the owner approves the screens"). Neither screen row exists in d2m,
and no request can create one:

- d2m's `screen:create` skill needs two quoted strings, `--name "<title>"` and the requirements.
  Given only a title, it stops with "pass its requirements in quotes" and writes nothing, but it
  exits 0, so d2m marked both earlier "Create screen" steps **done**. That is why two requests said
  "Ran: Create screen…" and nothing appeared.
- The request chain's action tool allows **one quoted string per command** and about 200 characters
  of requirements, so it cannot file a create that works. d2m refused the third request:
  "cannot be done: the chat's action tool allows one quoted string per command".
- `video-recorder` has Figma frames (3567:34892, 3567:34787), so `screen:create`, which is for
  requirements only with no Figma, is the wrong path anyway: it must be a row with Figma refs,
  specced by `/d2m:screen:spec`.
- A screen's requirements are the owner's own text, stored verbatim and never rewritten. Writing
  them into d2m behind the channel (its HTTP API) would be builder authoring design input, which
  `.claude/builder.md` §Design source forbids.

Even with the rows in place, the owner's approval of the d2m screens is a person's step (P2, and
the owner's 2026-11-20 rule: screens are approved before any wiring).

The server half is done: phases 2–3 are closed, verify phase GREEN at 7952fbf1, and the contract
froze 2026-11-22.

## What was tried
- Run 1–2 (2026-11-22/23): filed 7 d2m requests (ledger: library-home, activity-new,
  activities-editor, C-132, C-142, C-013, plus memo-detail asking d2m to mint both screens).
  `video-detail` / `video-recorder` were refused as unknown subjects.
- Run 3: re-requested the two creates through library-home (cmwsp258b004kv0tz9jna6yz7). It reported
  done; neither row exists.
- This run: traced the root cause in the d2m runs (below), then refiled
  (cmwspr1wa0001v0zxx3m8jdp9) with `--name` and quoted requirements in each step. d2m's chat
  answered `cannot be done:` because its action tool allows one quoted string. Nothing was filed.
- Considered and rejected: creating the rows through d2m's HTTP API (the New screen dialog's
  route). That bypasses the channel and writes the owner's requirements text for them.

## Evidence
- d2m run cmwsp2p2e004tv0tzmu5g6qdk (`/d2m:screen:create video-detail "Video Detail"`, exit 0)
  ends: "`get_screen("video-detail")` returned not found … The only quoted text in the arguments is
  "Video Detail", which I read as the screen's title. That leaves no requirements … the rules say to
  stop rather than call `create_screen`." The same happened in cmwsm4a66…, cmwsm4yib… and
  cmwsp3m2g…
- d2m run cmwspr1xm0008v0zxsvftq3yq (chat on this run's request): "cannot be done: the chat's action
  tool allows one quoted string per command, and these two creates need two. File nothing. … A
  requirements string over 200 characters … would also hit this tool's length limit."
- d2m `packages/skills/skills/screen-create/SKILL.md` §1: "Not found → requirements on the command
  line → create_screen(…) … No requirements → report `<screen> does not exist — pass its
  requirements in quotes` and stop."
- d2m's repo lane is slow, not stuck. At 03:37 UTC capture item cmwsm49mu000lv0fj0olqeokx (activity-new,
  every variant) had been running since 01:54 UTC, with stills landing 21:12 / 21:13 / 21:32 CST.
  Six apply/build runs queue behind it: activities-editor, C-132, C-142, library-home, C-013 and
  activity-new again. Their output lands **uncommitted in the main checkout on `main`**
  (activity-new's three files are already there), never on this branch.
- C-013 questions the earlier run answered for the owner, for review: the memo button stays at its
  current size; pressed is a 0.6 dim; there is no disabled state; the video button morphs from disc
  to square over about 200 ms.

## Where to dig
- d2m: `screen:create` exits 0 after a stop. The chain then marks the step done
  (`apps/server/src/services/projectChanges.ts` `resultOf` lists done steps as "Ran: …"). That is
  a d2m defect worth a d2m ticket: a create that wrote nothing should fail its step.
- d2m: the chat action tool's one-quoted-string rule (`bad_command`) makes `screen:create`
  impossible to file from any request.
- Not yet ruled out: whether the six queued d2m changes finish cleanly once the activity-new capture
  ends. Their stops and questions will need settling, and the owner's review of their uncommitted
  diff on `main`.

## Recommended next step
In the d2m app (Library namespace):
1. **New screen `video-detail`** ("Video Detail", pushed detail, from memo-detail). Suggested
   requirements, yours to edit: "Pushed iPhone page for one Library video, opened from a
   library-home video row. Like memo-detail: header with back and more; title renamed in place
   (1–120 chars); date and duration; a video player instead of the audio scrub/transport;
   timestamped transcript paragraphs, tap to seek, playing one highlighted. States: ready,
   processing, uploading, error, no transcript yet. More menu: Rename, Delete with confirmation."
2. **New screen `video-recorder`** ("Video Recorder") with Figma frames 3567:34892 and 3567:34787
   attached, then spec it (`/d2m:screen:spec video-recorder`; SPEC §iphone lists every state and
   component).
3. Let the six queued d2m changes finish, review and commit their output on `main`, and approve all
   eight subjects.
4. `/builder:agent --path docs/features/video-recorder`. The rerun files the spec/build requests for
   the two new screens if they are still unbuilt, records d2m's names, and builds phases 4–5.

Why this and not the alternatives:
- Retrying the request: it cannot work, because the chain's tool cannot carry the create.
- Builder writing the rows through d2m's API: that authors the owner's requirements.
- Starting phase 4 early: the SPEC forbids iPhone code before approval.

## History
- 2026-11-22 parked — d2m screens missing and not yet owner-approved (P2)
- 2026-11-23 parked — new Video Recorder and Video Detail screens are missing in d2m, and the owner must approve all d2m screens before iPhone code (P2)
- 2026-11-23 unparked by the fleet — automatic retry 1 of 2
- 2026-11-23 parked — root cause found: d2m requests cannot create screens (its chain tool takes one quoted string; the create skill needs two and exits 0 when it stops); owner creates both in the app, then approves (P2)
- 2026-11-23 unparked by a person — named to /builder:agent or /builder:fleet

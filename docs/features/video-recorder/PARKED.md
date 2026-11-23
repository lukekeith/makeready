# video-recorder — parked
parked: 2026-11-23 3562a388 · by the fleet (the run that parked it wrote no record)
kind: stuck
blocked: "new Video Recorder and Video Detail screens are missing in d2m, and the owner must approve all d2m screens before iPhone code (P2) — next: create both in d2m, approve the d2m changes, then /builder:agent --path docs/features/video-recorder"

## What is stuck
new Video Recorder and Video Detail screens are missing in d2m, and the owner must approve all d2m screens before iPhone code (P2)

## What was tried
- 3 fleet run(s) in all — `git log --oneline -- docs/features/video-recorder` lists what each changed

## Evidence
- the run that parked it: /Users/lukekeith/www/makeready/.builder/fleet/logs/video-recorder-03.log — its last lines:

```
- **Missing screens:** d2m twice reported creating `video-recorder` and `video-detail`, but neither exists. Their spec and build requests have never been filed.
- **Changes in flight:** six other d2m changes are still building: library-home, activity-new, activities-editor, C-132, C-142 and C-013. d2m writes its output uncommitted into your main checkout on `main`, not onto this branch, and the build doesn't commit there.

**Your steps:**
1. Create the two screens in d2m. The intents to file for them are in PLAN.md Task 1 and in d2m change `cmwsm1ny5002pv0tzqbh2f3rn`.
2. Review and approve all eight subjects.
3. Bring d2m's commits onto `builder/video-recorder`.

`docs/features/video-recorder/PARKED.md` has the change ids, what was tried and where to dig.

**Rulings I made:**
- **Server phases ran while d2m worked on phase 1.** Nothing on the server reads d2m output.
- **I started phase 3 before phase 2's verifier run finished.** If wrong, phase 3 would have needed rework; phase 2 then came back with one red, which was fixed.
- **I asked d2m to create the screens through other subjects**, because it refused them as unknown. If d2m can't do that, it's your step in the app, which is where this ended up.
- **No fix round for Task 6's Stream download code**, because it matches Cloudflare's docs. If the live API differs, the fallback transcripts fail on staging.
- **I parked instead of starting the iPhone state and services work.** The cost is the iPhone phases' time until you act.
- **I answered d2m's 7 questions on C-013 for you.** Please review them, listed in PARKED.md:
  - the memo button stays at its current size;
  - pressed is a 0.6 dim;
  - there is no disabled state;
  - the video button morphs from disc to square over about 200 ms.

Deferred minor findings are in the ledger for the final review. The one worth knowing: the Library query casts the user id column, which probably stops its index from being used. The cast should go on the parameter instead.

📍 video-recorder: building — parked (human-step): the two new d2m screens are missing and no screen is approved yet — next: create both screens in d2m and approve the d2m changes, then `/builder:agent --path docs/features/video-recorder`
```

## Where to dig
- start from the run's last lines above and the evidence it names; nothing has been ruled out yet

## Recommended next step
create both in d2m, approve the d2m changes, then /builder:agent --path docs/features/video-recorder

## History
- 2026-11-22 parked — d2m screens missing and not yet owner-approved (P2)
- 2026-11-23 parked — new Video Recorder and Video Detail screens are missing in d2m, and the owner must approve all d2m screens before iPhone code (P2)
- 2026-11-23 unparked by the fleet — automatic retry 1 of 2

# Phase 7 — Cross-app E2E  ·  app: cross-app

> Part of docs/features/highlighting/. Preconditions: **Phases 1–6 all VERIFIED.** The only phase
> that spans apps, and the last before the verify verdict.

## Goal

A highlight made by a leader on the iPhone reaches a member in the web player, with its note, in
the right colour, on the right block — and a build already in testers' hands keeps working
throughout. Walked live, not asserted.

## Companion skills

`/dev-start` for the local stack.

## Tasks — the walk (08 §Cross-app E2E walk)

- [ ] 7.1 iPhone, Read activity → highlight a verse → renders lime
- [ ] 7.2 The same activity in the web **LeaderApp** pane → same span, same colour
- [ ] 7.3 Enrol a member → open the lesson in the **member player** → same span, same colour
- [ ] 7.4 iPhone, Exegesis → highlight a phrase, add a note → the member player shows the note
- [ ] 7.5 **Highlight across two existing noted highlights → both notes survive**, end to end.
      This is Phase 1's guard proven at the system level, not just in a unit test
- [ ] 7.6 Kill and relaunch the iPhone app → highlights survive the disk-cache round trip
- [ ] 7.7 **Point a build-374 simulator build at the same server** → its Read highlights still
      render, from the retained `selections` projection. This is the backward-compatibility proof
      and the one step that cannot be inferred · spec: 02 §Backward compatibility, 09 §X-a
- [ ] 7.8 A multi-block READ activity: each block's highlights land on the right block on **both**
      consumers · spec: 03 §2.1, 09 §X-e

## Phase gates

Every app's gates, run fresh (08 §Gates) — server, client, iPhone and capture.

## Verification checklist

- [ ] All eight walk steps performed live against the local stack, not reasoned about
- [ ] 7.5 and 7.7 in particular were **actually executed** — they are the two the whole
      data-safety argument rests on
- [ ] Consumer parity: the fields 05 and 06 consume are identical, and both match 03's frozen table
- [ ] No `(claimed — unverified)` markers remain anywhere in the suite
- [ ] Local facts recorded in the ledger's env notes for whoever runs this next

## VERIFIED

*(unsigned)*

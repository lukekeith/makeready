# invite-member — parked
parked: 2026-10-26 fa5e385 · by build phase 4 (Task 11)
kind: human-step
blocked: "The invite page can't hide View invite or show its sent step after a send until the d2m screen update lands (D7) — next: /d2m:screen:update invite-member, then /builder:agent --path docs/features/invite-member"

## What is stuck
Only the last screen of the flow, the invite page itself (Task 11, `InviteMemberContainer`), is unbuilt.
Everything else is built and committed. The server stores and returns the invitee's name. The iPhone
Add-menu row opens the flow, the group picker is hosted with real data, and `sendInvite` posts the
contract body.

The d2m-built `InviteMemberScreen` cannot be hosted the way the SPEC requires:
- **It always shows View invite** on the sent step. D4 says Done only, until invite-home is wired.
- **It never leaves the step it was created on.** Its step is `@State` seeded once in `init`, so after an
  async send the host cannot move it to `sent`. That breaks D1's sent state and walk step 4.

D7 assigns both fixes to `/d2m:screen:update invite-member`: (a) a show-View-invite input,
default `true`, and (b) adoption of later `State.step` changes. That command belongs to the d2m pipeline.
Builder never writes `iphone/MakeReadyUI/**` (§Prototype frozen paths; global constraints), and the
d2m commands are not available to this run.

## What was tried
- Checked the view on this branch and on the target `ui2-preview-build`. Neither has the two inputs.
  `InviteMemberScreen.swift` is unchanged since `a95bcc9` (the module rename).
- Built Tasks 12 and 13 ahead of 11, since they don't depend on D7. Both are committed and reviewed (`fa5e385`).
- Did not work around it with `.id(step)` re-identity or by keeping View invite. D7 rejected both
  ("keep View invite + rebuild the view by identity — reverses D4, brittle").

- 2026-10-27 retry: re-checked the cause — it no longer holds. `e4a2264` added `showsViewInvite: Bool = true` and `.onChange(of: state.step)` adoption to `InviteMemberScreen.swift` in place (owner override, SPEC D7 superseded in `d66a63d`). Building Task 11 against those names.

## Evidence
- `iphone/MakeReadyUI/Screens/Groups/InviteMemberScreen.swift:54-71`: `init(state:onBack:onCancel:onSendInvite:onDone:onViewInvite:)` has no show-View-invite parameter, and `_step = SwiftUI.State(initialValue: Step(rawValue: state.step) ?? .name)` seeds the step once.
- `InviteMemberScreen.swift:226-233`: the sent step always draws `secondary: Self.viewInviteLabel, secondaryEnabled: true`.
- `UI2Shell.page(for:)` maps `.inviteMember` to `EmptyPage()` (Task 8 stub). Today a single-group leader, or a picker Select, lands on an empty page.

## Where to dig
- PLAN.md Task 11 is written and ready. Step 5's container code uses `showsViewInvite: false` and a `State.step` the screen adopts. Rename those to whatever the d2m update actually names them.
- SPEC D7 row: "Before the iphone phase, `/d2m:screen:update invite-member` … adds (a) a show-View-invite input, default `true`, and (b) adoption of later `State.step` changes".
- Not yet ruled out: the d2m update may name the inputs differently, or adopt `name`/`digits` as well as `step`. Task 11's container passes all three.

## Recommended next step
Run `/d2m:screen:update invite-member` to add the two inputs D7 names, then `/builder:agent --path docs/features/invite-member`.
That run builds Task 11 against the updated view, then walks, verifies and merges.
- A host-side workaround was rejected by D7.
- Re-ruling D4 to keep View invite would still leave the sent step unreachable, because (b) is required either way.

## History
- 2026-10-26 parked — the D7 d2m screen update has not landed; Task 11 cannot host the screen as specced
- 2026-10-27 unparked by a person — named to /builder:agent or /builder:fleet

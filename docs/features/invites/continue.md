# Continue — invites

## Last action
All eight tasks are coded at application source 89205782; independent task and whole-feature source reviews passed. Phase mvzdb14j-06f717 was GREEN. Acceptance remains incomplete, so this has not landed on feature/invites.

The actual owned-simulator walk found a menu callback bug in the D2M screen: FilterChip Menu fires onTap, while an unlabeled trailing closure bound onSelect. D2M request cmvze6lgr0001v0pvgiop6gv4 delivered the exact callback-only fix; it is integrated but uncommitted. A separate test-only patch isolates ActionStubTests' background-refresh failure from asynchronous join-request prefetch. The old held merge mvzdidvg-3d7f49 was deliberately cancelled because the app source changed; no result from it can authorize landing.

## Next action
Finish the current independent detail walk, then pause the walk driver. Restore only the owned transient harness/project/build-version changes, apply the prepared ActionStubTests patch, complete scoped review, commit the two fixes, and request fresh phase and held merge verification. Rebuild the owned walk app and re-walk all four filters plus outstanding detail/group-route items. Reuse unaffected actual walk evidence explicitly.

## Acceptance evidence so far
W1 five list statuses and W2 phone/group search reached on the real simulator. Direct W4/W5 Accept cancellation and approval passed; Requested-filter behavior awaits the fixed menu. W6 passed in the unchanged web client: David absent from the group before iPhone approval, then visible in the actual Members pane afterward (walk-evidence/web-before.*, web-member.*). W7 linked/unlinked detail and existing-member profile link reached. Resend, withdrawal/public link, rejection and existing group request route remain pending.

## Open threads
Walk driver owns only transient AgentWalk.swift/project references and simulator 50953498-A295-4806-A6C5-8DCBA5A19E80. Environment record: .builder/invites/walk-runtime.json; own DB and bucket use suffix 7ed780ea, server/client process groups 54260/54261. No fixture reset between approval and cross-app proof. Preserve all evidence before cleanup.

Primary checkout contains this build's exact temporary verifier config/helper and D2M delivery. Before landing, restore only matching own bytes using Git-common runtime-bootstrap/invites/record.json and .builder/invites/d2m-delivery-record.json, guarded against both working and HEAD hashes. Six overlaps are our own changes, not an owner decision. Other primary dirty work is protected.

## Constraints
No push, PR, deploy, real provider sends, shared dev migration, human simulator or dev-stack restart. Never read server/.env (a 1Password FIFO). Snapshots frozen at e9d897755a15ca48bffcd26e4709855e29f17c719c1e6c70d07852e905d98d9a. Agent-tested evidence is never human sign-off.

# Invites implementation and verification

The iPhone Invites tab replaces its empty page with a five-status invitation/request feed, phone/group search, four draft filters and pushed details. Leaders can confirm acceptance/rejection, resend eligible invitations and confirm withdrawal. Detail links use existing member/group destinations. Personal invitation state stays in memory and is cleared across sessions.

The server unifies invitation and join-request storage with an atomic generated migration, preserves legacy payloads, records history and enforces organization access and campaign admission. The existing web client consumes the preserved APIs without source changes. Released iPhone compatibility is protected by 75 immutable legacy response snapshots.

Verification: task-specific tests and independent reviews; final source review at 89205782 plus scoped callback/test review at aa547d20. Final source includes native fix aa547d20 and server withdrawn-landing fix 63056c4f. Phase mvzeyn2c-5d2d31 at fae9168f is GREEN (83s; 1 flake, 1 selected known failure). Held merged-result request mvzeynfn-a0b5b4 is GREEN (1104s), all four suites and configured checks, zero regressions or broken suites. Two flakes were classified (client tokenization and groups-edit-fields); twelve existing server UUID-test failures remain known debt. Green does not mean those known tests passed. Snapshot hash is unchanged: e9d897755a15ca48bffcd26e4709855e29f17c719c1e6c70d07852e905d98d9a.

Acceptance: all W1–W12 passed; see WALK.md for individual running-app results, original and fixed source identities, evidence and reused unaffected proof. The owned local environment uses test-mode SMS and fixture dev login. It proves neither real provider delivery nor OAuth. Five excluded legacy native view files received source/helper/syntax review; they were not runtime exercised as inactive views. Current compiled UI2 routes and state/action seams were tested.

Operational limits: local merge target feature/invites only; no push, PR, deployment or shared dev/production database migration. Agent-tested, not human-tested. Before the existing shared dev stack can use the new schema, apply the generated migration and regenerate Prisma under the owner's manual policy. Never read server/.env, which is a 1Password FIFO.

```sh
cd server/atlas && ../scripts/atlas.sh migrate apply --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev
docker exec makeready-server npx prisma generate
```

The configured dev fixture reset/smoke and any server restart are separate owner operations; they are not run by this agent handoff. The migration rewrites/removes legacy tables after preserving records and is not an additive rollout.

Suggested Standing trap for the owner (not added to config): “When a SwiftUI initializer has multiple defaulted closures, name action arguments explicitly; a trailing closure binds the last callback, which can silently disable a different control type.”

All eight implementation tasks are accepted. The local landing is released through the held merge queue after the exact final registry checkpoint is verified. No push or deployment is part of this delivery.

The actual walk found and closed two user-facing defects before delivery: inert filter chips (D2M callback fix) and withdrawn invalid HTML disappearing through immediate navigation. The latter is an explicit `(auto)` D5/C6 exception for the new withdrawn status; old status HTML/API responses remain unchanged. The coordinator also isolated a racing background-refresh test without suppressing production diagnostics.

Cleanup: only the owned walk process groups, simulator, database, bucket, temp build/results and expired fixture sessions were removed after preserving 185 native attachments, browser DOM/PNGs and debug logs. Shared services and protected primary-checkout work remain untouched. The feature worktree and evidence are retained.

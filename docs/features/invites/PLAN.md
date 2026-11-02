# Invites — executable integration plan

Goal: deliver the iPhone Invites tab and invite/request details on one shared invitation model, while keeping released iPhone and existing web leader contracts working. SPEC: `docs/features/invites/SPEC.md`, including the adopted 2026-11-02 compatibility and integration corrections. Architecture follows `server/.claude/CLAUDE.md`, `iphone/.claude/CLAUDE.md`, and `.claude/builder.md`; no root architecture specification exists.

Completion class: **integration**. Owner authorized agent build `--auto`, local landing to `feature/invites`, and the verifier configuration migration. Recommended recorded profile: **walk=risk review=slice**. Builder cost output is authoritative: eight task reviews plus one final review (nine total), with one final assembled risky-path walk; the five outcome slices below group those eight executable tasks. Tests run for every commit, phase close, and the merged result under the verifier regardless of walk profile. No new go-ahead ceremony is needed.

## Global constraints

- G1: each task owns exactly one configured app. Writers are sequential; dependencies below are acyclic. Planning/SPEC/manifest publication is coordinator-owned, not hidden inside an app task.
- G1a: every Builder CLI invocation uses `--target feature/invites`; never rely on the CLI default target main.
- G2: no production or makeready_dev DB changes, deployment, external SMS/push, human stack restart, human simulator, server environment-file reads, branch landing to main, or committed migration rewrites. Use Builder-owned scratch leases and owned simulators. Do not run unleased test commands.
- G3: schema source is YAML. Generated Prisma/HCL are generated, never hand edited. A schema cutover is not committed until every old Prisma reference and both server typechecks compile together.
- G4: baseline full JSON is captured while old models still exist. Baseline snapshots are immutable after Task 1. Only explicit D14 new-row expectations live in separate tests; do not normalize away missing fields/nullability/statuses. Existing focused tests may change only to use new Prisma mocks or necessary new model fields. One explicit D7 exception is `invite-member-integration.test.ts:330`: token-read status must remain pending instead of persisting expired; its HTTP baseline remains unchanged.
- G5: use existing auth, MembershipEvent and push patterns; no widening org permissions or opportunistic pre-existing client bug fixes. External services are mocked in tests. New public token payloads retain the exact legacy whitelist.
- G6: d2m owns MakeReadyUI views. Coordinator must use `check_project_change` and the returned handover, requesting changes where needed. Tasks consume delivered props; they do not directly edit design source or bypass a rejected check.
- G7: producers freeze C1–C7 after Task 5 verification; consumers use the corrected verbatim wire definitions below. No file persistence for invitation state. Respect cancellation, retired sessions and 401 policy.
- G8: commands shown in tasks run only inside the configured verifier lease (scratch URLs set before imports, dummy integrations, production smoke excluded). The verifier owns full suites/checks; workers can request focused red/green runs. Each task commits only its own app files under project conventions and requests commit verification, then waits for its phase result.

## Acceptance

A1 legacy full-body compatibility; A2 lossless migration; A3 atomic lifecycle/cross-acceptance; A4 scoped feed/detail; A5 resend/withdraw/clicks; A6 iPhone state/session reconciliation; A7 tab/search/filters; A8 details/navigation/confirmations; A9 assembled compatibility walk. Definitions are in SPEC Completion and acceptance.

## Slices

| Slice | Outcome / demo | Acceptance | Risk | Depends | Proof |
|---|---|---|---|---|---|
| S01 | Existing recipients and leaders use unchanged endpoints after one-table migration | A1,A2 | high | [] | old-table baseline + SQL migration edge cases + same snapshots on new model |
| S02 | Sending against a request and requesting against an invite each produce one accepted relationship | A3,A5 | high | [S01] | transactional/concurrency tests; known-token click tests |
| S03 | Manageable-org feed/detail and resend/withdraw work with history and SMS failures | A4,A5 | high | [S02] | scoped request tests, campaign batch tests, deterministic fixtures |
| S04 | iPhone Home → Invites shows/filter/searches server rows with safe session state | A6,A7 | medium | [S03] | DTO/action/mapper tests and app build |
| S05 | Leader confirms request decisions, resends and withdraws in pushed details; web stays consistent | A6,A8,A9 | high | [S04] | detail/action/navigation tests + one assembled simulator/browser walk |

## Phases

| Phase | Slice | App | Tasks | Goal |
|---|---|---|---|---|
| 1 | S01 | server | 1 | Capture old-schema truth safely |
| 2 | S01 | server | 2 | Lossless schema and compile-coherent legacy cutover |
| 3 | S02 | server | 3 | Atomic lifecycle and public-link history |
| 4 | S03 | server | 4 | Scoped feed/detail contract |
| 5 | S03 | server | 5 | Mutations, fixtures and producer freeze |
| 6 | S04 | iphone | 6 | Frozen DTOs, stores and safe actions |
| 7 | S04 | iphone | 7 | Invites tab and typed row dispatch |
| 8 | S05 | iphone | 8 | Pushed details and assembled behavior |

## Proof strategy

Task 1 proves A1 against the old schema; Task 2 reruns that evidence and proves A2 with real migration SQL. Task 3 proves A3 and the click/withdrawn-link portion of A5. Task 4 proves A4. Task 5 proves remaining A5 and freezes C1–C7. Task 6 proves A6 through injected API/session tests. Task 7 proves A7. Task 8 proves A8 and authors the risky walk for A9. Merge verification additionally runs unchanged client Vitest/PHPUnit, client build/stories, server suites/types/schema, iPhone XCTest/build and configured lint comparisons. No client task is planned because no client source change is required.

Final assembled walk runs once in the Builder-owned scratch environment: five-status feed; Requested filter; request confirmation cancel (no write) then Accept; Accepted row; web group membership visible; linked and unlinked details; Resend feedback; Withdraw cancel then confirm; row disappears; old token renders invalid/expired. A second request is rejected with confirmation and reopens as rejected without pending actions. Capture screenshots inside XCUITest at assertions and inspect web DOM/API state, never a post-test simulator home screenshot. Fixture send timestamps/logs permit the resend test without bypassing rate limits. If d2m or infrastructure is blocked, record actual evidence and do not claim integrated completion.

## Integration preflight

- D2M handover before Task 7/8: InvitesHome needs one-TopNav composition, focus-or-query callback, disabling view-owned local search, Members-style pinned search; both detail screens need external-header composition; InviteHome needs capabilities and busy inputs plus a missing-age display. Additive defaults must preserve existing previews. Exact proposal appears in the iPhone audit; check behavior/layout changes through the owner workflow, not an assumed fast lane. Coordinator records delivered prop names before these tasks start.
- C1/C2 fields and D21 confirmation copy are explicit in SPEC D24 and Wire nullability and exact new payloads. A null organization never enters new APIs; nullable phone/group remain representable. Accepted/rejected request rows route by kind, regardless of which screen callback fired.
- Task 2 is deliberately larger than an isolated DDL commit: generated Prisma deletion would break services, fixtures and tests if separated. All files share server ownership. Later lifecycle tasks improve transitions without invalid intermediate compilation.
- Configuration uses existing local Postgres only to create owned scratch leases. No `docker restart`, default `schema:diff` shared dev DB, production probes, or inherited server environment loading is part of this plan.
- Shared service/route files recur only in sequential tasks. iPhone state precedes view wiring. No parallel writers or cross-app task blocks.

### Task 1: Capture full legacy contracts against the old schema
App: server
Phase: 1
Slice: S01
Depends: []
Acceptance: A1,A2
Recipe: server YAML/Atlas workflow and Builder isolated verifier
Role: implementation

**Files:**
- Create `server/test/helpers/invitations-legacy-fixtures.ts` — deterministic old-table fixtures, member/user auth helpers, explicit dynamic-scalar capture and scratch URL refusal.
- Create `server/test/invitations-legacy-contract.test.ts` and its Vitest snapshot — complete legacy HTTP/body baseline.
- Create `server/test/helpers/invitations-migration-db.ts` — owned scratch migration DB creation/cleanup and old-schema replay for later SQL tests; accepts only local verifier DB names.
- Modify `server/test/setup.ts` only if required to make invitation suites use already leased URLs without environment fallback; retain safe existing test behavior and avoid unrelated test cleanup.

**Interfaces:**
- Produces `seedLegacyInvitationCases(prisma)` returning deterministic IDs for pending/accepted/stored-expired/time-expired/null-group/null-phone/unresolved-org invites and pending/approved/rejected requests with dates/reviewer values.
- Produces `captureLegacyResponse(response, generatedValues)` returning the complete body with only validated newly generated scalar IDs/tokens/clock values aliased; seeded values remain exact. Assert generated values against the actual persisted row before aliasing; never remove keys or alter null/type/status.
- Produces `withInvitationMigrationDb(run)` accepting an async callback with a scratch DB URL and closing/dropping only its own database. Replay committed Atlas history through the revision before the invitation merge.
- Consumes C5–C7 and the supplemental embedded legacy contracts from corrected D2.

**Behaviour:**
- Capture GET/POST `/api/invites`, `/send`, PATCH/DELETE by ID, direct request POST, `/me`, list, approve/reject and admin list with original auth/status/envelopes, plus public token/landing and embedded member/group/verification responses (D2,G4).
- Include absence/null fields and full raw-request fields, generic `{}` creation, public recipientName absence, status vocabulary and unauthorized responses; mock campaign/verification/push only, not invitation storage (D2,G5).
- Tests refuse any missing/non-loopback/non-verifier URL before ORM import, do not invoke live probes, and cleanup only their owned rows/databases (G2,G8).
- Capture old D14 rerequest reset as characterization evidence, but isolate it from immutable snapshots that later test the intentionally changed D14 outcome (D14,G4).

**Pattern:** `server/src/routes/__tests__/invites-send-name.request.test.ts:39`; `server/fixtures/__tests__/db-harness.ts:29`; `server/test/helpers/api-auth.ts:19`.

**Tests:**
- `legacy contracts capture complete bodies` and `public token data stays whitelisted`:
```ts
expect(captureLegacyResponse(res, generatedValues)).toMatchSnapshot();
expect(adminApproved.body.requests[0]).toHaveProperty('updatedAt', approved.updatedAt.toISOString());
expect(adminApproved.body.requests[0].status).toBe('approved');
expect(Object.keys(adminApproved.body).sort()).toEqual(['count', 'requests', 'success']);
expect(Object.keys(approvedResponse.body).sort()).toEqual(['member', 'request', 'success']);
expect(Object.keys(rejectedResponse.body).sort()).toEqual(['request', 'success']);
expect(generic.body.invite.groupId).toBeNull();
expect(generic.body.invite.expiresAt).toBeNull();
expect(publicLookup.body.invite).not.toHaveProperty('recipientName');
expect(unauthorized.status).toBe(401);
```
- `scratch harness fails closed` and `old rerequest behavior is characterized separately`:
```ts
expect(() => assertInvitationTestDatabase('postgresql://postgres:postgres@localhost:5434/makeready_dev')).toThrow();
expect(() => assertInvitationTestDatabase(undefined)).toThrow();
expect(oldRerequest.body.request.id).toBe(rejectedRequest.id);
expect(smsMock).toHaveBeenCalled();
expect(liveTwilioTransport).not.toHaveBeenCalled();
expect(livePushTransport).not.toHaveBeenCalled();
```

**Steps:**
1. Implement guarded fixtures/harness and characterization cases while the old generated models remain unchanged. Baseline characterization should pass against current behavior; do not force a fake red phase or fix unrelated legacy behavior.
2. In the lease run `npm run test:run -- test/invitations-legacy-contract.test.ts`; inspect every snapshot for full body coverage and dynamic alias whitelist. Run once to capture. If the verifier generated snapshots inside its disposable checkout, copy those exact snapshot artifacts back to the authorized worktree, inspect them, then rerun without update against that committed candidate to prove stability; never substitute handwritten expected JSON for uncaptured behavior.
3. Run `npx --no-install tsc --noEmit` and `npx --no-install tsc --noEmit -p fixtures` through verifier; no schema edits in this task.
4. Commit server characterization/harness only; request commit/phase verification. Freeze baseline files before Task 2.

### Task 2: Migrate losslessly and cut every legacy reader/writer over coherently
App: server
Phase: 2
Slice: S01
Depends: [1]
Acceptance: A1,A2
Recipe: server YAML-first Atlas workflow with explicit scratch diff URLs
Role: implementation

**Files:**
- Modify `server/schema/schema.yaml`, generate `server/prisma/schema.prisma` and `server/atlas/.schema.hcl`; add one new `server/atlas/migrations/*_invitations.sql` and update `atlas.sum` — shared schema/data transfer.
- Create `server/src/services/invitation.ts` — legacy compatibility repository, explicit serializers and shared row types.
- Modify `server/src/services/invite.ts`; `server/src/routes/invites.ts`, `group-join-requests.ts`, `verification.ts`, `members.ts`, `groups.ts`, `join.ts`; `server/src/index.ts` — replace every old model access while preserving endpoint behavior/envelopes.
- Modify `server/fixtures/screens/invite-member.ts`, `groups-detail.ts`; `server/fixtures/__tests__/invite-member.db.test.ts`, `groups-browse.db.test.ts`; `server/prisma/seed-dev.ts` — seeds/fixtures/cleanup on new models.
- Modify `server/src/services/__tests__/invite-recipient-name.test.ts`; `server/src/routes/__tests__/invites-recipient-name-reads.request.test.ts`, `invite-member-integration.test.ts`; `server/test/invite-authorization.test.ts` — only necessary model/mocks/fixture adaptation.
- Modify `server/test/helpers/invitations-legacy-fixtures.ts` and storage-only lookups in `server/test/invitations-legacy-contract.test.ts` — same logical cases on new storage, preferably through the fixture adapter; immutable snapshot bytes/HTTP expectations stay unchanged. D14 remains separate.
- Create `server/test/invitations-migration.test.ts` and `server/test/invitations-legacy-serializers.test.ts` — actual SQL preservation and field whitelist proof.

**Interfaces:**
- Produces `toLegacyInvite(row)` and `toLegacyJoinRequest(row)` with exactly old scalar names; request accepted maps to approved, responded fields map to reviewed fields, stored updatedAt survives. Routes retain their own existing response envelopes/selections.
- Produces `resolveLegacyInvitationOrganization(groupId, inviterId)` returning group org, valid historical inviter org, single unambiguous owned/role org, or null; no arbitrary first org.
- Produces `Invitation` and `InviteEvent` generated models as corrected D1/SC1/SC2; consumes Task 1 seed/capture/migration harness.
- Migration schema: Invitation has UUID id, required initiatedBy/status/createdAt/updatedAt, nullable token(unique), inviterId, memberId, groupId, organizationId, recipientPhone, recipientName, message, respondedById, respondedAt, acceptedAt, expiresAt. Indexes `(organizationId,createdAt)`, `(recipientPhone)`, `(groupId,memberId)`, `(groupId,status)`, `(memberId)`. Preserve old group/inviter/member/reviewer relationship deletion behavior where applicable; organization relation is nullable with SetNull; event invitation FK cascades, event actorId/groupId are nullable scalar history identifiers. InviteEvent fields/id/type/at/metadata follow D6, with `(invitationId,at)` index. No old group/member full unique key and no ActivityLog FK.
- Migration algorithm: within one transaction create new tables, collision preflight abort, copy invites with all original scalars and `updatedAt=createdAt`, copy requests with original updatedAt and reviewed→responded fields, approved→accepted, phone from Member, org from Group; backfill only date-supported sent/accepted/requested/approved/rejected/expired events; preserve ActivityLog values; verify counts then drop old tables. No reverse data-deleting script.

**Behaviour:**
- Preserve null generic identity/org, original IDs/tokens/dates/status and all raw legacy fields; group-less unknown-org rows remain legacy-accessible (D1–D3).
- Existing routes/auth/errors remain compatible while reads/writes use only the new models; explicit serializers prevent extra Invitation fields leaking into raw legacy responses (D2,G3–G5).
- Collision, impossible copy or FK failure aborts the full migration; old data and tables remain intact on failure; no old committed SQL is changed (D3,G2).
- Existing tests are adapted only for model/mocks in this task; S1 snapshots remain unchanged and both source/fixture compilation passes in this same commit (G3,G4).

**Tests:**
- `migration preserves source scalars and event dates`, `unresolved generic invitations survive`, `collision rolls back`, `legacy serializer preserves reviewed and updated fields`:
```ts
expect(after.invitationIds.sort()).toEqual(before.sourceIds.sort());
expect(after.invitesById[id].token).toBe(before.invitesById[id].token);
expect(after.requestsById[requestId].updatedAt).toEqual(before.requestsById[requestId].updatedAt);
expect(after.invitationsById[genericId].organizationId).toBeNull();
expect(after.activityInviteIds).toEqual(before.activityInviteIds);
expect(after.oldTables).toEqual([]);
expect(after.eventsFor(approvedId).map(e => [e.type, e.at])).toEqual([['requested', requestCreatedAt], ['approved', reviewedAt]]);
expect(collisionResult.succeeded).toBe(false);
expect(collisionResult.oldRows).toEqual(collisionInput.oldRows);
expect(toLegacyJoinRequest(accepted)).toEqual(oldApprovedScalars);
expect(toLegacyJoinRequest(accepted)).not.toHaveProperty('initiatedBy');
```

**Steps:**
1. Add migration/serializer tests from the existing harness and run focused tests red without changing snapshots.
2. Edit YAML; run `npm run schema:validate`, `npm run schema:generate`; invoke Atlas diff with explicit owned scratch dev URL rather than default local config. Review generated DDL, add copy/backfill/preflight before drops, recalculate Atlas checksum, and run `npx --no-install prisma generate`.
3. Implement all mapped legacy replacements and seed/test adapters together. Do not commit a partially removed Prisma model.
4. In leases run `npm run test:run -- test/invitations-migration.test.ts test/invitations-legacy-serializers.test.ts test/invitations-legacy-contract.test.ts`, both TypeScript commands from Task 1 and `npm run schema:validate`.
5. Inspect `rg -n '\\.(invite|groupJoinRequest)\\b' src fixtures prisma/seed-dev.ts test` from server; only explicit old-table migration/characterization text may remain. Commit coherent server cutover, request verification and S01 review.

### Task 3: Make invitation lifecycle transitions atomic and retain public link history
App: server
Phase: 3
Slice: S02
Depends: [2]
Acceptance: A1,A3,A5
Recipe: transactional service extraction and focused concurrency tests
Role: implementation

**Files:**
- Modify `server/src/services/invitation.ts` — transition, request, cross-acceptance and click functions.
- Modify `server/src/services/invite.ts`; `server/src/routes/invites.ts`, `group-join-requests.ts`, `members.ts`, `groups.ts`, `verification.ts`, `join.ts` — delegate lifecycle while preserving response adapters.
- Create `server/test/invitations-lifecycle.test.ts`, `server/test/invitations-links.test.ts` — state, concurrency and public privacy tests.
- Modify `server/src/routes/__tests__/invite-member-integration.test.ts:330` only to assert D7 read-only expiry (pending remains pending), preserving all response assertions.

**Interfaces:**
- Produces `recordEvent(tx, input)` writing invitationId/type/at/actorId/groupId/metadata inside caller transaction.
- Produces `submitInvitationRequest(memberId, groupId, message)` returning the legacy result discriminator (joined, pending-created, duplicate-pending, already-member) plus row when applicable.
- Produces `decideInvitationRequest(requestId, groupId, actorId, decision)` for approve/reject, preserving legacy errors and membership effects.
- Produces `recordInvitationLinkClick(invitationId, now)` and `acceptInvitationByToken(token, actor)` used by the existing recipient routes; public serialized payload unchanged.
- Transition algorithm: lock the affected invitation and stable group/person key inside a DB transaction (transaction advisory lock keyed by canonical group/person, plus current row read), reread pending eligibility, write membership/org membership/row/event atomically, retry serialization conflicts with a bounded three-attempt policy; no SMS/push inside retried transaction. Request and send paths share that lock key. The click operation locks the invitation then reads latest click and inserts only when last click is at least ten minutes old.

**Behaviour:**
- D12 approves the existing member request without a second row; D13 accepts existing pending invite without a request row; membership uniqueness and old auto-join response remain (D12,D13,A3).
- Generic invite POST remains phone-less; D12 send adapter preserves legacy envelope using existing request ID and group-code join URL, with SMS failure leaving domain unchanged (corrected D12).
- D14 creates a new row after reviewed history and `/me`/group lookup selects latest; member confirmation uses the same history rule; duplicate pending/already-member responses remain exact (D14,D2).
- Review writes event and membership transactionally while established MembershipEvent/push behavior remains; competing decisions cannot both succeed (D6,G5).
- Token GET records throttled known-token clicks, never rewrites expiry, and rejects withdrawn with existing invalid response; reset-to-pending PATCH adds no false resend event and retains old API behavior (D5–D7).

**Tests:**
- `cross acceptance has one relationship and membership`, `rerequest preserves history`, `concurrent decisions have one winner`:
```ts
expect(await invitations.count({ where: { groupId, recipientPhone } })).toBe(1);
expect(await groupMembers.count({ where: { groupId, memberId, isActive: true } })).toBe(1);
expect(await memberOrganizations.count({ where: { memberId, organizationId } })).toBe(1);
expect(crossSend.body.inviteId).toBe(pendingRequestId);
expect(crossSend.body.inviteUrl).toBe(`${clientUrl}/join/group/${groupCode}`);
expect(requestAgainstInvite.body).toEqual({ success: true, status: 'joined' });
expect(rerequest.id).not.toBe(rejected.id);
expect(await invitations.findUnique({ where: { id: rejected.id } })).toMatchObject({ status: 'rejected' });
expect(me.body.request.id).toBe(rerequest.id);
expect(decisions.filter(r => r.status === 200)).toHaveLength(1);
expect(terminalEvents).toHaveLength(1);
```
- `known token clicks throttle across both routes`, `withdrawn links and legacy reset`:
```ts
expect(clicksAtNineMinutes).toHaveLength(1);
expect(clicksAtTenMinutes).toHaveLength(2);
expect(expiredRowAfterRead.status).toBe('pending');
expect(withdrawnLookup.body).toEqual(expiredLookup.body);
expect(withdrawnLanding.text).toContain('Invite Not Found');
expect(publicLookup.body.invite).not.toHaveProperty('recipientName');
expect(eventsAfterPendingReset).toEqual(eventsBeforePendingReset);
expect(explicitExpiredPatchEvents.map(e => e.type)).toEqual(['expired']);
expect(repeatedSameStatusPatchEvents).toEqual(explicitExpiredPatchEvents);
```

**Steps:**
1. Write the lifecycle/link tests, including parallel calls with barriers and mocked SMS/push, then request red focused runs.
2. Implement shared locks/transitions/serializers and route delegation; retain existing push deep link and MembershipEvent payloads.
3. Run `npm run test:run -- test/invitations-lifecycle.test.ts test/invitations-links.test.ts test/invitations-legacy-contract.test.ts` in lease plus both server typechecks. Do not update baseline snapshots.
4. Commit server lifecycle changes, request commit/phase verification and S02 review.

### Task 4: Produce the scoped feed and detail wire contract
App: server
Phase: 4
Slice: S03
Depends: [3]
Acceptance: A4
Recipe: thin Express routes over scoped service reads
Role: implementation

**Files:**
- Create `server/src/routes/invitations.ts` — C1/C2 validation/auth/OpenAPI.
- Modify `server/src/services/invitation.ts` — status/date, org scope, filters, feed/detail projections.
- Modify `server/src/index.ts` — register `/api/invitations` without shadowing feed with `/:id`.
- Create `server/test/invitations-read.test.ts` — scoped request and projection contract tests.

**Interfaces:**
- Produces `getInvitationFeed(userId, filters, now)` returning C1 and `getInvitationDetail(userId, invitationId, now)` returning C2; both use existing permission service and return 403/404 typed errors as corrected contract specifies.
- Produces `invitationDisplayStatus(row, now)` and `invitationDisplayDate(row, now)` total functions for stored historical values.
- Frozen producer wire types (all nullable keys are emitted; ISO timestamps; exact C1/C2):
```ts
type InvitationKind = 'invite' | 'request';
type InvitationDisplayStatus = 'sent' | 'requested' | 'accepted' | 'rejected' | 'expired';
type InvitationEventType = 'sent' | 'resent' | 'link_clicked' | 'accepted' | 'withdrawn' | 'expired' | 'requested' | 'approved' | 'rejected';
interface InvitationFeedItem {
  id: string; kind: InvitationKind; status: InvitationDisplayStatus;
  recipientPhone: string | null; recipientName: string | null; memberId: string | null;
  groupId: string | null; groupName: string | null; organizationId: string;
  inviterId: string | null; inviterName: string | null; date: string; createdAt: string;
}
interface InvitationFeed {
  items: InvitationFeedItem[]; total: number;
  filters: {orgs: {id: string; name: string}[]; groups: {id: string; name: string; organizationId: string}[]; leaders: {id: string; name: string}[]};
}
interface InvitationDetail {
  id: string; kind: InvitationKind; status: InvitationDisplayStatus | 'withdrawn';
  recipientPhone: string | null; recipientName: string | null; inviterName: string | null; message: string | null; createdAt: string;
  member: {id: string; name: string; picture: string | null; age: number | null; role: string | null; birthday: string | null; joinedAt: string | null} | null;
  invitations: {id: string; kind: InvitationKind; groupId: string | null; groupName: string | null; groupPicture: string | null; status: InvitationDisplayStatus | 'withdrawn'; date: string}[];
  events: {id: string; type: InvitationEventType; at: string; groupId: string | null; groupName: string | null; invitationId: string}[];
  canResend: boolean; canWithdraw: boolean;
}
```
- C1: GET `/api/invitations/feed?orgId&groupId&leaderId&status&limit`; UUID filters optional; status closed five values; limit integer 1–200 default 200; no q. C2: GET `/api/invitations/:id`. Errors `{error: string}`, 400 invalid filter/401 unauthenticated/403 known out-of-scope detail/404 absent.

**Behaviour:**
- Scope every row, related invitation, event and filter option to owned/role orgs or super-admin all non-null orgs; creator-only cannot expand org scope and null-org rows never enter new APIs (D9,D17).
- Filter statuses before limit, order display date then id descending, count before cap, include all permitted filter options independent of selected chips; leader filter includes sender invites and requests in groups creator/org-role leader manages (D7–D10).
- Detail includes selected row, phone-equal permitted rows/history newest first; null phone selects only self; link member by stored memberId or exact normalized phone within selected org (D18).
- Exclude withdrawn from feed, include it in detail; canResend excludes expired/null-phone; canWithdraw includes expired pending but excludes null-phone; dates always fallback without data rewrites (D5,D7,D10,D15,D16).

**Tests:**
- `feed scopes all projections and sorts display dates before limiting`, `leader matches requests`, `detail isolates phone/org and nullable rows`:
```ts
expect(new Set(feed.items.map(x => x.status))).toEqual(new Set(['sent','requested','accepted','rejected','expired']));
expect(stranger.body.items).toEqual([]);
expect(superAdmin.body.items.some(x => x.id === unknownOrgId)).toBe(false);
expect(feed.body.filters.orgs.map(x => x.id)).not.toContain(otherOrgId);
expect(recentAccepted.body.items[0].id).toBe(oldCreatedRecentlyAcceptedId);
expect(limited.body.items).toHaveLength(200);
expect(limited.body.total).toBe(201);
expect(leaderFiltered.body.items.map(x => x.id)).toContain(pendingRequestId);
expect(nullPhoneDetail.body.invitations.map(x => x.id)).toEqual([nullPhoneId]);
expect(nullPhoneDetail.body).toMatchObject({ recipientPhone: null, canResend: false, canWithdraw: false });
expect(expiredPendingDetail.body).toMatchObject({ canResend: false, canWithdraw: true });
expect(detail.body.inviterName).toBe('Fixture Leader');
expect(missingDecisionDate.body.items[0].date).toBe(createdAt.toISOString());
expect(forbidden.status).toBe(403);
expect(missing.status).toBe(404);
expect(invalidLimit.status).toBe(400);
```

**Steps:**
1. Write read/authorization/edge-case tests and run `npm run test:run -- test/invitations-read.test.ts` red in lease.
2. Implement scoped service queries, total mapping and thin routes/OpenAPI; do not fetch 200 then sort/filter in memory incorrectly.
3. Run focused tests green plus `test/invitations-legacy-contract.test.ts` and both server typechecks; inspect sample C1/C2 JSON against verbatim types.
4. Commit server feed/detail; request commit/phase verification. Contract freeze waits until Task 5.

### Task 5: Deliver batch resend, withdrawal and deterministic feature fixtures
App: server
Phase: 5
Slice: S03
Depends: [4]
Acceptance: A4,A5,A9
Recipe: campaign-admitted batch, transactional domain mutations, fixture layer conventions
Role: implementation

**Files:**
- Modify `server/src/services/sms-campaign.ts` — shared singleton/batch rate admission and factual delivery logs.
- Modify `server/src/services/invitation.ts`, `server/src/routes/invitations.ts` — C3/C4 actions and refreshed detail responses.
- Create `server/fixtures/screens/invites-home.ts`, `invite-home.ts`, `request-detail.ts`; modify `server/fixtures/ids.ts` as needed — feature fixture identities/history.
- Create `server/test/invitations-mutations.test.ts`, `server/test/invitations-sms-batch.test.ts`, `server/fixtures/__tests__/invitations.db.test.ts` — eligibility/failure/concurrency/fixture proof.

**Interfaces:**
- Produces `sendCampaignSmsBatch(messages)` returning per-message campaign results plus aggregate success; existing `sendCampaignSms(params)` keeps its signature and participates in the same admission by a one-message batch.
- Batch admission validates all message contexts/lengths and recipient consent, obtains a transaction advisory lock on template/phone, checks existing window, creates QUEUED SmsLog reservations for admitted messages, then releases before delivery. Singleton callers use same lock. Sibling reservations do not reject one admitted batch; separate calls do. Delivery updates actual log statuses; unsent reserved messages become FAILED on aborted batch. Never log a success for an undelivered message or rollback real send history.
- Produces `resendInvitations(userId, invitationId, now)` and `withdrawInvitations(userId, invitationId, now)` returning C2. C3 POST `/api/invitations/:id/resend`; C4 POST `/api/invitations/:id/withdraw`; auth 401/403/404, no eligible rows 409, any campaign failure 502 for C3.
- Resend gathers permitted same-phone nonexpired pending leader rows, reuses tokens, sends admitted batch, then transactionally rechecks each pending row and sets expiry to now+7 days/writes resent for eligible rows only. Any delivery failure leaves all invitation rows/events unchanged. Withdraw atomically changes all permitted same-phone pending leader rows, including expired pending, and writes withdrawn; accepted rows untouched.

**Behaviour:**
- Authorize selected row first; null phone cannot expand identity or mutate; phone-wide actions cannot touch other-org/member/nonpending rows (D15–D17).
- Keep tokens, reset successful eligible expiry seven days, preserve invitation state on SMS failure and factual logs on partial delivery; no rate-limit or consent bypass (D15,corrected failure semantics).
- Concurrent withdrawal/acceptance is not overwritten by resend; concurrent sends share normal campaign admission (D6,D15,D16).
- Full fixture covers all five statuses across two groups/two leaders; invite detail has sent+accepted, linked member and at least five events; request detail has pending request and at least two real-taxonomy events. Fixtures use no live SMS and support the walk's resend without a fresh rate-blocking log (fixture contract,G2).

**Tests:**
- `same-phone batch admits once and preserves original tokens`, `failure on second SMS changes no invitation`, `withdraw includes expired pending`, `concurrent withdrawal wins`:
```ts
expect(sentUrls).toEqual(originalTokenUrls);
expect(successRows.every(r => r.expiresAt.toISOString() === sevenDaysLater)).toBe(true);
expect(resentEvents).toHaveLength(2);
expect(secondSendFailure.status).toBe(502);
expect(afterFailure.invitationRows).toEqual(beforeFailure.invitationRows);
expect(afterFailure.inviteEvents).toEqual(beforeFailure.inviteEvents);
expect(afterFailure.smsLogs.map(x => x.status)).toEqual(['SENT','FAILED']);
expect(concurrentAdmissionSuccesses).toHaveLength(1);
expect(optedOut.status).toBe(502);
expect(withdrawnExpired.status).toBe('withdrawn');
expect(acceptedAfterWithdraw.status).toBe('accepted');
expect(otherOrgAfter).toEqual(otherOrgBefore);
expect(nullPhoneMutation.status).toBe(409);
expect(racedWithdrawal.status).toBe('withdrawn');
expect(fixtureStatuses).toEqual(expect.arrayContaining(['sent','requested','accepted','rejected','expired']));
expect(inviteDetail.events.length).toBeGreaterThanOrEqual(5);
expect(requestDetail.events.length).toBeGreaterThanOrEqual(2);
```

**Steps:**
1. Add batch/mutation/fixture tests; mock Twilio transport and push before imports. Run the three new suites red inside leases.
2. Implement campaign admission and mutations, then fixture layers with stable IDs and time-relative statuses; keep existing campaign template/consent behavior.
3. Run `npm run test:run -- test/invitations-mutations.test.ts test/invitations-sms-batch.test.ts fixtures/__tests__/invitations.db.test.ts`, legacy baseline, both typechecks and schema validation; request full server phase suite.
4. Commit server task; after passing review record C1–C7 producer freeze and S03 review evidence. Coordinator hands exact payload examples/types to iPhone tasks.

### Task 6: Add frozen iPhone models, session state and reconciled actions
App: iphone
Phase: 6
Slice: S04
Depends: [5]
Acceptance: A6
Recipe: AppState EntityStore plus injectable Actions pattern
Role: implementation

**Files:**
- Create `iphone/MakeReady/State/Models/InvitationModels.swift` — frozen C1/C2 Codable/Identifiable types and query/window values.
- Create `iphone/MakeReady/State/Actions/InvitationActions.swift` — feed/detail/mutations and request decision orchestration.
- Modify `iphone/MakeReady/State/AppState.swift` — invitation stores/window/filters/staleness and clearInMemory integration.
- Modify `iphone/MakeReady/State/Actions/InviteActions.swift`, `GroupActions.swift` — safe invalidation from existing send/create/decision paths without wire changes.
- Create `iphone/MakeReadyCaptureTests/InvitationActionsTests.swift`, `InvitationModelsTests.swift`; modify `StubAPIClient.swift` only for missing reusable test hooks.
- Modify `iphone/MakeReady.xcodeproj/project.pbxproj` only for required app/test file membership.

**Interfaces:**
- Consumes frozen Task 4 `InvitationFeed`, `InvitationDetail`, Task 5 mutation responses, and unchanged C5 decision endpoints.
- Produces Swift `InvitationFeedItem`, `InvitationFeedResponse`, `InvitationDetail`, `InvitationQuery` (orgId/groupId/leaderId/status, no search), `InvitationFeedWindow` (query, orderedIDs, total), `InvitationFilters`, `InvitationActionError`.
- Produces AppState `invitations: EntityStore<InvitationFeedItem>`, `invitationDetails: [String: InvitationDetail]`, `invitationFeedWindow: InvitationFeedWindow?`, `invitationFilters: InvitationFilters?`, and staleness tracked per feed/detail; cleared with session.
- Produces `InvitationActions(api:state:now:onUnauthorized:)` with `loadInvitationFeed(_ query:)`, `loadInvitation(_ id:)`, `resendInvitation(_ id:)`, `withdrawInvitation(_ id:)`, `approveRequest(id:groupId:)`, `rejectRequest(id:groupId:)`; async typed Results, mutation success remains success after follow-up refresh failure.
- Decision actions invoke existing GroupActions methods. After committed decision remove pending badge, retire stale selected detail/related cached details, reconcile or invalidate group membership/detail/member projections and refresh active feed/detail. Store a known reviewed state or remove stale detail before refresh so pending actions cannot reappear on failed GET. Existing InviteActions gains injectable state defaulting to AppState.shared for invalidation.

**Behaviour:**
- Decode explicit nulls and historical status values without changing released Invite/JoinRequest DTOs (C1,C2,D2,G7).
- Feed window replacement controls visibility independently of entity retention; query identity and session generation reject stale out-of-order completions (D22).
- Merge mutation C2 and invalidate affected sibling details; refresh active feed and legacy pending requests; sending invalidates newly relevant invitation state (D22).
- Cancellation/retired sessions write nothing, 401 signs out via injected callback, transient refresh failure preserves committed success and cached valid data; clear all personal invitation state on session end (D22,G7).

**Pattern:** `MemberActions.swift:18,114`; `AppState.swift:951`; `GroupActions.swift:723`; `MakeReadyCaptureTests/MemberActionsTests.swift:63`.

**Tests:**
- `nullable contract decodes`, `new query replaces ordered window`, `retired session cannot merge`, `mutation committed refresh failure stays successful`, `legacy decisions/send invalidate projections`:
```swift
XCTAssertNil(detail.recipientPhone)
XCTAssertNil(detail.invitations[0].groupId)
XCTAssertNil(detail.member?.age)
XCTAssertEqual(state.invitationFeedWindow?.orderedIDs, ["requested-row"])
XCTAssertTrue(state.invitations.contains("old-retained-row"))
XCTAssertNil(retiredState.invitationFeedWindow)
XCTAssertEqual(unauthorizedCalls, 1)
XCTAssertTrue(committedResult.isSuccess)
XCTAssertFalse(state.pendingJoinRequestsByGroupId[groupID, default: []].contains { $0.id == requestID })
XCTAssertNotEqual(state.invitationDetails[requestID]?.status, .requested)
XCTAssertNil(state.invitationDetails[siblingID])
XCTAssertTrue(state.invitationFeedIsStale)
```
Use the actual EntityStore membership API if it differs from `contains`; assertions must preserve these outcomes rather than introduce new store APIs only for tests.

**Steps:**
1. Write model/action tests using StubAPIClient and independent AppState; request focused XCTest red runs in the verifier's owned simulator.
2. Implement DTOs/actions/state/invalidation; keep old method signatures source-compatible with defaults. Add target membership.
3. In iPhone lease run `xcodebuild test -project MakeReady.xcodeproj -scheme MakeReady -configuration Debug -destination "id=$SIMULATOR_UDID" -derivedDataPath "$BUILDER_VERIFY_TMP/DerivedData" API_BASE_URL=http://127.0.0.1:1 -only-testing:MakeReadyCaptureTests/InvitationActionsTests -only-testing:MakeReadyCaptureTests/InvitationModelsTests`; request configured SwiftLint comparison.
4. Commit iphone-only state/actions, request commit/phase verification. No d2m-owned source edits.

### Task 7: Wire the Invites tab, debounced local search and draft filters
App: iphone
Phase: 7
Slice: S04
Depends: [6]
Acceptance: A6,A7
Recipe: MembersHomeContainer/Mapper pattern with delivered d2m input contract
Role: implementation

**Files:**
- Create `iphone/MakeReady/UI2/Containers/Invites/InvitesHomeContainer.swift`, `InvitesHomeMapper.swift` — presentation/state mapping and action wiring.
- Modify `iphone/MakeReady/UI2/Shell/UI2Shell.swift` — register `.invites` content; expose a typed row-selection callback on the container. Final destination registration and callback-to-push integration belong to Task 8, so this task introduces no empty detail destinations.
- Create `iphone/MakeReadyCaptureTests/InvitesHomeMapperTests.swift`; modify `UI2ShellModelTests.swift`, `AppTargetMembershipTests.swift`, and project membership as needed.

**Interfaces:**
- Consumes Task 6 state/actions and d2m-delivered InvitesHome integration props: single navigation owner, onSearchActiveChange, externally controlled local search projection, and Members-style pinning. Coordinator supplies actual checked/delivered names before dispatch.
- Produces `InvitesHomeMapper.Selection` with search plus single optional org/group/leader/status IDs; `output(window:entities:filters:selection:now:timeZone:)` yields screen state and stable `selection(atRow:)` based on C1 kind. `InvitationRowSelection` has invite(id:) and request(id:) cases; the container exposes that selection through an injected onOpen callback, connected to UI2 navigation in Task 8.
- Produces `InvitesHomeContainer.searchDebounce = .milliseconds(300)`, cancellable local search projection task, filter-driven server load task, `.pageRefresh` integration and `UI2HidesTopNavKey` focus-or-query preference.

**Behaviour:**
- Render only current ordered feed window; local search matches phone/group within it after 300 ms, never server q; retain stable IDs/kinds through filtering (D9,D11,D22).
- Four C-036 menus each use draft single-selection with All first, Clear changes draft, Save commits and reloads; cancel does not alter applied filters (D11).
- One shell TopNav, hidden during focus or nonempty query; no additional root scroll; cached-first/error/empty/no-results follow existing screen contract; pull refresh reloads active query; cancel load on disappear (D11,D23).
- Both screen row callbacks dispatch a typed selection by row kind, so accepted/rejected requests retain request identity for Task 8 navigation; TopNav plus remains no-op (D11,D20,out-of-scope).

**Tests:**
- `five display statuses map to C089`, `local search preserves kind and IDs`, `single-select draft filter isolation`, `date and empty states`:
```swift
XCTAssertEqual(output.statuses, ["sent", "requested", "accepted", "rejected", "expired"])
XCTAssertEqual(filtered.selection(atRow: 0), .request(id: "accepted-request"))
XCTAssertEqual(InvitesHomeContainer.searchDebounce, .milliseconds(300))
XCTAssertEqual(appliedSelection.orgID, originalOrgID)
XCTAssertNil(clearedDraft.orgID)
XCTAssertNil(savedSelection.orgID)
XCTAssertEqual(output.rowDate(at: 0), "Just now")
XCTAssertEqual(oldOutput.rowDate(at: 0), "Nov 1, 2026")
XCTAssertEqual(emptyOutput.mode, .empty)
XCTAssertEqual(noResultsOutput.mode, .noResults)
XCTAssertFalse(requestedPaths.contains { $0.contains("q=") })
```
Assertions can target mapper outputs' actual typed C-089 enum names, but the five wire→display mappings and dates are fixed.

**Steps:**
1. Verify completed d2m handover before consuming props. If required inputs are absent, report the concrete missing contract to coordinator; do not edit MakeReadyUI.
2. Write mapper/navigation tests red, then implement selection/mapper/container and shell section wiring with the injectable typed row callback. Do not add an empty destination page.
3. Run the Task 6 xcodebuild command with `-only-testing:MakeReadyCaptureTests/InvitesHomeMapperTests -only-testing:MakeReadyCaptureTests/UI2ShellModelTests -only-testing:MakeReadyCaptureTests/AppTargetMembershipTests`, then configured iPhone checks.
4. Commit iphone-only tab work; request commit/phase verification and S04 review. Task 8 connects the typed row callback to complete pushed destinations before integration completion; S04 proof here covers list/search/filter output and row identity.

### Task 8: Complete pushed details, confirmations and integrated acceptance proof
App: iphone
Phase: 8
Slice: S05
Depends: [7]
Acceptance: A6,A8,A9
Recipe: pinned UI2 detail containers and existing ActionMenuOverlay confirmations
Role: implementation

**Files:**
- Create `iphone/MakeReady/UI2/Containers/Invites/InviteDetailContainer.swift`, `InviteDetailMapper.swift`, `RequestDetailContainer.swift`, `RequestDetailMapper.swift` — C2 rendering, actions, confirmations and links.
- Modify `iphone/MakeReady/UI2/Shell/UI2Shell.swift` and `UI2ShellModel.swift` — register/render `.inviteDetail(id:)` and `.requestDetail(id:)`, and connect the tab row callback to navigator.push; modify `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift` only to route existing request rows to `.requestDetail(id:)` where needed.
- Create `iphone/MakeReadyCaptureTests/InvitationDetailMapperTests.swift`, `InvitationDetailActionsTests.swift`; modify `UI2ShellModelTests.swift` and app/test project membership.
- The coordinator owns the configured transient `iphone/MakeReadyCaptureUITests/AgentWalk.swift` harness and its cleanup; this app task adds no permanent UI-test file. Unit tests and exact walk assertions below are mandatory.

**Interfaces:**
- Consumes C2, Task 6 action Results, Task 7 typed row selections, and d2m-delivered capability/busy/external-header/missing-age props. Selection entry is `detail.invitations.first { $0.id == detail.id }`, not the first aggregate row.
- Produces invite/request mapper output with matching parallel arrays, selected group ID for C5/navigation, stable member links, neutral request timeline and correct request vocabulary requested→pending/accepted→approved/rejected→rejected.
- Produces confirmation state in the container using C-066 host. Accept copy: `Accept join request?`, `«phone» will be added to «group».`, Cancel/Accept. Reject copy: `Reject join request?`, `«phone» will not be added to «group».`, Cancel/Reject destructive. Withdraw copy remains `Withdraw invitation?`, `«phone» will no longer be able to join with this invitation.`, Cancel/Withdraw destructive. Default request copy is auto-assumed in corrected D21.

**Behaviour:**
- Detail is a typed pushed page with pinned existing PageHeader, scroll body, one header owner, cached content during refresh and cold header/back only until data; no invented skeleton/modal navigation (D23).
- Render selected row's inviterName, nullable phone/group/member metadata using corrected fallbacks; missing age never displays 0; member link opens existing member destination, request group link existing group destination; sent invitation chevron remains deferred (D18,out-of-scope).
- Request kind survives review and chips use Requested/Approved/Rejected vocabulary; pending alone offers Accept/Reject; both confirm, cancel sends no request, double taps cannot duplicate in-flight mutation; successful committed decision pops even if refresh failed (D20–D22).
- Resend honors canResend, shows `Invitation resent` on committed success; withdrawal honors independent canWithdraw and confirmation, updates detail chips and feed; busy disables both mutation buttons while back/member navigation remains; failures use top error banner without fabricated success (D15–D17,D23).
- Integration walk proves the actual built routes/refresh/membership/link behavior against the same scratch server and unchanged web client; do not claim completion from mocked unit tests alone (A9,G2).

**Pattern:** `GroupDetailContainer.swift:40`; `EnrollChecklistContainer.swift:88`; `UI2Navigation.swift:136`; `RequestDetailScreen.swift:63` owner confirmation comment.

**Tests:**
- `selected detail entry and nullable presentation`, `reviewed requests retain request destination`, `confirmation cancellation and committed success`, `independent busy capabilities`:
```swift
XCTAssertEqual(requestOutput.groupID, selectedRequestGroupID)
XCTAssertEqual(requestOutput.status, "approved")
XCTAssertEqual(inviteOutput.phone, "No phone number")
XCTAssertEqual(inviteOutput.groupTitles, ["No group"])
XCTAssertEqual(inviteOutput.ageDisplay, "—")
XCTAssertEqual(inviteOutput.invitedBy, "Fixture Leader")
XCTAssertEqual(cancelledDecisionPosts, 0)
XCTAssertEqual(confirmedDecisionPosts, 1)
XCTAssertEqual(popCountAfterCommittedRefreshFailure, 1)
XCTAssertFalse(expiredPendingOutput.canResend)
XCTAssertTrue(expiredPendingOutput.canWithdraw)
XCTAssertFalse(busyOutput.actionsEnabled)
XCTAssertEqual(resendToast, "Invitation resent")
XCTAssertEqual(withdrawnOutput.groupStatuses, ["Withdrawn"])
```
- Integration assertions: Requested filter contains pending request; cancel keeps it pending; confirmed accept changes row to Accepted and web group's member list contains the member ID; resend produces one toast; cancel withdrawal preserves row; confirmed withdrawal removes feed row and token browser page contains `Invite Not Found` (or unchanged client expired equivalent); rejected request reopens with Rejected chip and no pending action controls. Capture screenshots/DOM at each assertion in the configured walk.

**Steps:**
1. Verify exact delivered d2m props; write detail mapper/action tests red using injected actions/clock and container-owned confirmation state.
2. Implement mappers/containers, typed links, confirmations and error/toast hosting; connect typed row selections to the complete destinations and check target membership. No MakeReadyUI source edits.
3. Run Task 6 xcodebuild command targeting InvitationDetailMapperTests, InvitationDetailActionsTests, UI2ShellModelTests, and InvitationActionsTests; request full iPhone phase checks.
4. Commit iphone-only detail work; request verification and S05 review. Coordinator assembles all apps, runs merge-tier server/client/iPhone suites/checks, executes the single risky-path walk described above, and lands only on feature/invites after all required integration evidence passes.

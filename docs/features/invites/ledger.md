# Invites ledger

- Recovered spec-only feature from committed 9bc0bf7d into builder/invites. Origin and target: feature/invites at that commit, per project branch policy. Legacy branch: main is a stale spec field, not a prior landing transaction. No earlier build identity, plan, implementation or verification exists.
- Authorization: agent build with --auto; owner explicitly approved Builder config update.

## Setup and audit
- Owner approved shared Builder config update. Integration worker verifier_config: gpt-6.1-sol/medium. Read-only audits server_audit and iphone_audit: gpt-6-astra/high. Roles selected by route.mjs, no fallbacks.
- Agent-ready accepted spec phase, target feature/invites, isolated builder/invites worktree. Do not rerun eligibility during this handoff.
- Recommended tests: walk=risk review=slice (project standard default, raised walk for breaking schema/released consumer/auth). Full verifier floors remain.
- check-obligations: every cross-section obligation discharged; independent audit still identified legacy nullable fields/callers and screen input gaps requiring reconciliation before freeze.
- D2M get_rules and summary/sections for invites-home, invite-home, request-detail fetched over MCP into scratch. Design views remain D2M-owned and input changes require check_project_change.

## env notes
- Root .project/ARCHITECTURE_SPEC.md is absent at the committed feature tip. Use actual per-app .claude instructions and existing implementation as architecture evidence; do not fabricate that file.
- Main checkout has owner changes to CLAUDE/settings/hooks, Info.plist, enrollment files and untracked docs/config. They remain there; this build starts solely from committed 9bc0bf7d.
- Setup commit 85deb44a: owner-approved verifier configuration + helper. Independent task review found missing helper on target checkouts; fixed via agent_walk.copy; config loaders confirm 4 suites and 7 checks; node syntax and diff checks pass. Commit-tier request mvyw7gox-019e1d queued against feature/invites.
- Runtime bootstrap: verifier service reads main checkout config. Installed exactly the reviewed config/helper there without committing or touching app/owner files. Original config and installed SHA256 hashes are saved in Git-common builder-codex/runtime-bootstrap/invites. Before final local landing, restore only this build's exact matching install; never overwrite later owner edits. Helper was originally absent.
- Approved tests walk=risk review=slice, local immutable target feature/invites, within original --auto authorization.
- Commit verifier mvyw7gox-019e1d GREEN at 85deb44ac83f49bf30becfef15ede23f3b0b48bb (17s), zero regressions/broken checks. This is setup commit evidence only; feature behavior is not implemented or verified yet.

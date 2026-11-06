size: md
state: building
next: /builder:resume --path docs/features/staging-fixtures
head: f23d62d8
ticket: none
branch: builder/staging-fixtures
pr: none
apps: server+iphone
contract: frozen 2026-11-05
hold: none
go-ahead: auto (recommended) 2026-11-05
tests: walk=none review=app
target: main
walk: none
verify: none
ready: pending "dev env (fleet walk lane)"
auto: on 2026-11-05
blocked: "config change needed — the Staging and Release app builds have never been run, and the check that runs them is not in the verifier's config — next: apply the diff in PARKED.md to .claude/builder.md on main, then /builder:agent"
agent-walk: on 2026-11-05

size: lg
state: building
next: /builder:resume --path docs/features/group-cover-image
head: 09216fd
ticket: none
branch: builder/group-cover-image
pr: none
apps: server+iphone
contract: frozen 2026-10-27
hold: none
go-ahead: Luke 2026-10-27
tests: slice=own+app end=risk review=slice
target: main
walk: none
verify: none
ready: pending "dev env (fleet walk lane)"
auto: on 2026-10-27
blocked: "config change needed — agent_walk.env has no R2 credentials, so every cover save on the walk 500s [F10] — next: apply the diff in PARKED.md to .claude/builder.md on main, then /builder:agent --path docs/features/group-cover-image"
agent-walk: on 2026-10-27

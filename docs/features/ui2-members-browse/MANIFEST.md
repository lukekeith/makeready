size: lg
state: building
next: /builder:resume --path docs/features/ui2-members-browse
head: f329b92
ticket: none
branch: builder/ui2-members-browse
pr: none
apps: server+iphone
contract: frozen 2026-10-26
hold: none
go-ahead: auto (recommended) 2026-10-25
tests: slice=own+app end=risk review=slice
target: ui2-preview-build
walk: none
verify: none
ready: none
ui2: members-home, members-profile (via program ui2-members)
auto: on 2026-10-25
blocked: "iPhone commits are yours to approve (commit: manual); the server half is built and its contract frozen — next: /builder:resume --path docs/features/ui2-members-browse, approving each staged iPhone task"
agent-walk: on 2026-10-25

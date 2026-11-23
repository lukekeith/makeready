size: lg
state: building
next: /builder:resume --path docs/features/video-recorder
head: 23eba0bb
ticket: none
branch: builder/video-recorder
pr: none
apps: server+iphone
contract: frozen 2026-11-22
hold: none
go-ahead: auto (recommended) 2026-11-22
tests: walk=risk review=slice
target: main
walk: none
verify: none
ready: none
ui2: none (phase 1 — d2m specs video-recorder, video-detail and the library-home change from doc source, P2)
auto: on 2026-11-22
blocked: "the video recorder and video detail screens are fully built in d2m and wait on the owner's approval before any iPhone code (P2) — next: review and commit the d2m output on main, approve the screens, then /builder:agent"
agent-walk: on 2026-11-22

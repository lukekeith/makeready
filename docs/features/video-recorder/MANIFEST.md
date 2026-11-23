size: lg
state: building
next: /builder:resume --path docs/features/video-recorder
head: 365d4dc0
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
blocked: "new Video Recorder and Video Detail screens are missing in d2m, and the owner must approve all d2m screens before iPhone code (P2) — next: create both in d2m, approve the d2m changes, then /builder:agent --path docs/features/video-recorder"
agent-walk: on 2026-11-22

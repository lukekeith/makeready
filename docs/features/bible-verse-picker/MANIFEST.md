size: lg
state: building
next: /builder:resume --path docs/features/bible-verse-picker
head: 42153e34
ticket: none
branch: builder/bible-verse-picker
pr: none
apps: server+iphone
contract: frozen 2026-11-10
hold: none
go-ahead: auto (recommended) 2026-11-10
tests: walk=none review=end human=yes
target: main
walk: none
verify: none
ready: pending "API.Bible key in walk env"
ui2: none
auto: on 2026-11-10
blocked: "the walk env has no API.Bible key, so every Bible screen and search in the picker fails before an agent can walk it — next: export API_BIBLE_KEY in the shell that runs the fleet, then /builder:agent"
agent-walk: on 2026-11-10

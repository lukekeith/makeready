size: lg
state: building
next: /builder:resume --path docs/features/bible-verse-picker
head: 9cbfce14
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
ready: none
ui2: none
auto: on 2026-11-10
blocked: "the Bible picker's four pages (books, chapters, verses, reader) can't be built until they exist as d2m screens, and only the owner's screen spec can create them — next: /ui2-screen bible-books, bible-chapters, bible-verses, bible-reader, then /builder:agent"
agent-walk: on 2026-11-10

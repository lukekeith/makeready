# bible-verse-picker — parked
parked: 2026-11-11 6c0eaef6 · by resume (fleet walk lane, walk readiness)
kind: human-step
blocked: "the walk env has no API.Bible key, so every Bible screen and search in the picker fails before an agent can walk it — next: export API_BIBLE_KEY in the shell that runs the fleet, then /builder:agent"

## What is stuck
The build is finished. All phases are closed, the four d2m picker screens exist, and C-140 BibleVerseReader is built. The
earlier park cause (no d2m screens) is gone. What blocks the walk now is the walk env. The server
starts without `API_BIBLE_KEY`, so every Bible request fails with a 500 before any of this feature's
code runs: translations, books, chapter verses and smart search. All 7 walk.md items need live Bible
text (Books groups, search "john 3:16", Reader selection, Change passage, split of 3:1–36, WEB
switch), so an agent walk would fail every item on the env, not on the feature.

## What was tried
- Walk readiness, 2026-11-11 at 6c0eaef6: main@388d0abf is merged in. The branch adds no migrations and has no Prisma
  schema change, so nothing needs regenerating. `agent_walk.smoke` passes (health, :8102 client, :9010 R2).
- Exercised the changed surfaces on :3110. `GET /api/search/recent` → 200. `DELETE /api/search/recent/<missing>`
  → 404 (correct). `GET /api/bible/translations`, `…/translations/ENGKJV/books`,
  `…/ENGKJV/43/3/verses?start=16&end=18` and `POST /api/search/smart {"query":"John 3:16"}` all → 500.
- Looked for a way to serve Bible text without the key. `getAvailableBibles`
  (server/src/services/bible-metadata.ts:71) serves from `api_bible_versions` while it has unexpired
  rows and calls API.Bible otherwise. makeready_walk has 0 version rows and 0 `bible_content_cache` rows. The
  owner's makeready_dev has 39 version rows (all expired) and 0 content rows, so copying its cache in would not help.
  The dev container (makeready-server) does have the key, from its 1Password-piped .env.
- Ruled out putting the key in `.claude/builder.md` `agent_walk.env`: that file is committed, and a secret must
  not be. Also ruled out restarting the walk env with the key: the fleet owns that process (REFERENCE §Walk readiness).

## Evidence
- .builder/walk-server.log (git-ignored), quoted:
  "Error fetching translations: Error: [api-bible] API_BIBLE_KEY environment variable is not set"
  "Error fetching books: Error: [api-bible] API_BIBLE_KEY environment variable is not set"
  "Smart search error: Error: [api-bible] API_BIBLE_KEY environment variable is not set"
- .claude/builder.md `agent_walk.env` sets PORT, DATABASE_URL, GOOGLE_*, R2_*, SESSION_SECRET …, and no API_BIBLE_KEY.
- builder scripts/fleet.mjs `envFor`: "const env = { ...process.env }", then agent_walk.env on top for the
  walk lane. The walk env inherits whatever the fleet's own shell exports.

## Where to dig
- The shell that launches `/builder:agent` / the fleet: export API_BIBLE_KEY there (an `op read` of the
  same 1Password item server/.env uses). The fleet then passes it to the walk server, with no config change.
- Not yet ruled out: whether the walk should instead seed `api_bible_versions` + `bible_content_cache`
  for ENGKJV/WEB John 3 from a fixture, so walks never need the key. That would mean a fixtures change (server),
  which is a scope decision for the owner.
- Readiness otherwise passed. Once the key is present, re-run readiness's endpoint checks above, then
  `advance.mjs … --set state=built --set "ready=yes <date> <sha>"` and `/builder:agent-walk`.

## Recommended next step
Export API_BIBLE_KEY in the shell that runs the fleet, then `/builder:agent --path docs/features/bible-verse-picker`.
It needs no committed secret and no code. Alternatives: put the key in agent_walk.env (commits a secret);
seed a Bible cache fixture (new server scope, and only covers the seeded chapters); walk without it (every item fails on the env).

## History
- 2026-11-10 parked — d2m cannot create the four picker screens; the screens are the owner's /ui2-screen step
- 2026-11-11 parked — the four Bible picker screens do not exist in d2m, and only the owner's /ui2-screen can create them
- 2026-11-11 unparked by the fleet — automatic retry 1 of 2
- 2026-11-10 parked again (human-step) — re-verified: still no such screens, still no tool that creates one
- 2026-11-11 unparked by a person — named to /builder:agent or /builder:fleet
- 2026-11-11 unparked by the fleet for the walk lane; d2m screens now exist (old cause cleared)
- 2026-11-11 parked (human-step) — walk env has no API_BIBLE_KEY; every Bible surface 500s before the walk
- 2026-11-11 unparked by a person — named to /builder:agent or /builder:fleet

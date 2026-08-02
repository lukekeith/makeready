# 03 — Data & API contract

**Not affected** — this feature changes where the iPhone client *holds* data it already fetches. It
adds no table, no column, no migration, and no endpoint.

Because there is no contract, there is **no contract freeze** in this feature's build: consumer
phases have no server phase to wait on (see [02-app-impact.md](02-app-impact.md) § Cross-app
sequencing).

## Schema

No `server/schema/` YAML change, no Prisma model change, no Atlas migration.

## Endpoints

The Actions reshaped by Phase B call existing endpoints and keep their current request/response
shapes. What changes is client-side only: the Action writes the response into `AppState` instead of
returning it to a caller that caches a private copy.

| Action (`ProgramActions.swift:402-495`) | Contract change |
|---|---|
| `loadAllTags` | none — response now written to `AppState.allProgramTags` instead of returned |
| `loadGroupLeaders` | none — response now written to `AppState.groupLeaders` instead of returned |
| `getTags` | none |
| `addTags` / `removeTags` / `syncTags` | none on the wire; each gains a client-side refresh of the derived tag list in the same call |
| `suggestTags` | none |
| `loadAllMediaTags` (`MediaActions.swift:410`) | none |

`/build-spec-audit` should still confirm that each of these Actions' current response shape is what
`AppState` will store — a mismatch would be a `G#`, not an `X#`, since no producer changes.

## Client-side persistence format

**No change — `D1` DECIDED (Luke, 2026-08-01): memory-only.** The new collections are plain
`@Observable` properties on `AppState`; **`PersistedState.swift` is not edited at all**, and G1's
seven-site wiring is out of scope. The table below is retained only as the record of what option (b)
would have cost.

<details><summary>Superseded — the persistence wiring option (b) would have required</summary>

| File | Line | Role |
|---|---|---|
| `PersistedState.swift` | `:58` | the persisted field |
| `PersistedState.swift` | `:123` | default init |
| `PersistedState.swift` | `:210` | snapshot from `AppState` |
| `PersistedState.swift` | `:246` | `CodingKeys` |
| `PersistedState.swift` | `:291` | decode — `decodeIfPresent(…) ?? []` |

`:291`'s `decodeIfPresent(…) ?? []` makes added fields backward compatible by construction.
**verified in code (2026-08-01)**

</details>

**Consequence of memory-only:** tags, leaders, and media tags are refetched after every launch and
after sign-out. That is the intended trade — they are cheap, they change often, and the pattern
they follow (`homeHeatmapData`) is the one that already clears correctly on logout, which
`textThemes` does not (G2/D2).

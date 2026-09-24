#!/usr/bin/env node
/**
 * Resolve a `--ui2 <ref>` into the exact set of UI 2.0 components a prototype-mode run operates
 * on — the MakeReady analogue of a Storybook title path. It is the ONE place a ref is resolved,
 * so /builder:check and /builder:brainstorm agree on what is in scope.
 *
 * The registry is `docs/ui2/design-system/registry.md` — one pipe-table row per component
 * (`| C-### | Name | Status | Platform | Figma ref | Variants/states | Props | Defined in |
 * Consumed by |`), the table header repeating per block. Screens are `docs/ui2/screens/<id>.md`.
 *
 * Three ref kinds:
 *   screen     `home-dashboard`, `screens/home-dashboard`, `docs/ui2/screens/home-dashboard.md`
 *              → the screen plus every registry row whose "Consumed by" names it. The section-
 *              family case: take it whole, because half a screen is not a screen.
 *   component  `C-034`, or a registry Name (`SearchField`)
 *              → that one row, plus the rows it consumes (its dependencies).
 *   set        `C-034,C-035` — an explicit comma list; taken exactly as given.
 *
 *   node .claude/scripts/list-ui2-refs.mjs                          # list every screen + row
 *   node .claude/scripts/list-ui2-refs.mjs --resolve "<ref>"        # human-readable tree
 *   node .claude/scripts/list-ui2-refs.mjs --resolve "<ref>" --json # machine-readable
 *
 * Exit codes: 0 resolved · 3 ambiguous (a Name matching >1 row) · 4 not found (nearest
 * candidates printed on stderr) · 2 bad usage.
 */
import { readdirSync, readFileSync, existsSync } from 'node:fs'
import { join, basename } from 'node:path'

const ROOT = process.cwd()
const REGISTRY = 'docs/ui2/design-system/registry.md'
const SCREENS = 'docs/ui2/screens'
const CONTRACTS = 'docs/ui2/design-system/components'

const args = process.argv.slice(2)
const asJson = args.includes('--json')
const ri = args.indexOf('--resolve')
const ref = ri >= 0 ? args[ri + 1] : null
if (ri >= 0 && (!ref || ref.startsWith('--'))) {
  console.error('usage: list-ui2-refs.mjs --resolve "<C-### | Name | screen-id | C-a,C-b>" [--json]')
  process.exit(2)
}

const read = (p) => {
  try {
    return readFileSync(p, 'utf8')
  } catch {
    return null
  }
}

const registryText = read(join(ROOT, REGISTRY))
if (!registryText) {
  console.error(`No ${REGISTRY} — this repo has no UI 2.0 registry, so there is no --ui2 ref to resolve.`)
  process.exit(2)
}

/**
 * Registry rows. A cell may itself contain `|` inside inline code or a bold list, so the split is
 * on the row's own pipes and short rows are skipped rather than guessed at.
 */
const parseRegistry = (text) => {
  const rows = []
  for (const line of text.split('\n')) {
    if (!/^\|\s*C-\d{3}/.test(line)) continue
    const cells = line.replace(/^\|/, '').replace(/\|\s*$/, '').split('|').map((c) => c.trim())
    if (cells.length < 9) continue
    // A middle cell (Figma ref, Variants, Props) can itself contain `|` inside inline code or a
    // bold list, which shifts every later cell left. So anchor from BOTH ends — the four leading
    // columns and the two trailing ones are fixed — and treat whatever is left as the middle.
    const [id, name, status, platform] = cells
    const consumedBy = cells[cells.length - 1]
    const definedIn = cells[cells.length - 2]
    const middle = cells.slice(4, cells.length - 2)
    const [figma = '', variants = '', ...restProps] = middle
    const props = restProps.length ? restProps.join(' | ') : (middle[2] ?? '')
    rows.push({
      id,
      // Names carry parentheticals: "MetaPair (renamed from MetaLabel 2026-09-02; ID stable)".
      name: name.replace(/\s*\(.*$/, '').trim(),
      nameRaw: name,
      status,
      platform,
      figma,
      variants,
      props,
      definedIn,
      consumedBy,
      struck: /^~~/.test(id) || /^~~/.test(name),
    })
  }
  return rows
}

const rows = parseRegistry(registryText).filter((r) => !r.struck)
const byId = new Map(rows.map((r) => [r.id, r]))

const screenIds = existsSync(join(ROOT, SCREENS))
  ? readdirSync(join(ROOT, SCREENS))
      .filter((f) => f.endsWith('.md'))
      .map((f) => basename(f, '.md'))
      .sort()
  : []

/** The contract file a row's "Defined in" points at, when it has its own file. */
const contractFile = (row) => {
  const m = row.definedIn.match(/([\w/.-]*C-\d{3}[\w.-]*\.md)/)
  if (!m) return null
  const p = m[1].startsWith('design-system/') ? `docs/ui2/${m[1]}` : join(CONTRACTS, basename(m[1]))
  return existsSync(join(ROOT, p)) ? p : null
}

/** Rows whose "Consumed by" names this screen id. */
const rowsForScreen = (id) =>
  rows.filter((r) => new RegExp(`\\b${id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`).test(r.consumedBy))

/** Rows this row consumes — "Consumed by" is the reverse edge, so read the C-### ids in its own
 *  contract + variants cells. A dependency is a row this one renders, not one that renders it. */
const dependenciesOf = (row) => {
  const text = [row.variants, row.props, read(join(ROOT, contractFile(row) ?? '')) ?? ''].join('\n')
  const ids = new Set()
  for (const m of text.matchAll(/\bC-(\d{3})\b/g)) {
    const id = `C-${m[1]}`
    if (id !== row.id && byId.has(id)) ids.add(id)
  }
  return [...ids].sort()
}

const normalize = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '')

const resolve = (raw) => {
  const r = raw.trim()

  // --- an explicit set ---
  if (/,/.test(r)) {
    const ids = r.split(',').map((x) => x.trim().toUpperCase())
    const missing = ids.filter((id) => !byId.has(id))
    if (missing.length) return { kind: 'miss', tried: r, candidates: missing.map((m) => `${m} — no such row`) }
    return { kind: 'set', title: ids.join(', '), components: ids.map((id) => byId.get(id)) }
  }

  // --- a component id ---
  const idMatch = r.match(/^(?:C-)?(\d{3})$/i) ?? r.match(/\b[Cc]-(\d{3})\b/)
  if (idMatch) {
    const id = `C-${idMatch[1]}`
    const row = byId.get(id)
    if (!row) return { kind: 'miss', tried: id, candidates: [...byId.keys()].slice(0, 12) }
    return { kind: 'component', title: `${row.id} ${row.name}`, components: [row] }
  }

  // --- a screen ---
  const screenGuess = basename(r.replace(/\.md$/, ''))
  if (screenIds.includes(screenGuess)) {
    const consumed = rowsForScreen(screenGuess)
    return {
      kind: 'screen',
      title: screenGuess,
      screen: `${SCREENS}/${screenGuess}.md`,
      components: consumed,
    }
  }

  // --- a registry Name ---
  const hits = rows.filter((row) => normalize(row.name) === normalize(r))
  if (hits.length === 1) return { kind: 'component', title: `${hits[0].id} ${hits[0].name}`, components: hits }
  if (hits.length > 1)
    return { kind: 'ambiguous', tried: r, candidates: hits.map((h) => `${h.id} ${h.name} — ${h.definedIn}`) }

  // --- near misses, so a typo prints its neighbours rather than nothing ---
  const n = normalize(r)
  const near = [
    ...screenIds.filter((s) => normalize(s).includes(n) || n.includes(normalize(s))).map((s) => `screen ${s}`),
    ...rows
      .filter((row) => normalize(row.name).includes(n) || n.includes(normalize(row.name)))
      .map((row) => `${row.id} ${row.name}`),
  ].slice(0, 12)
  return { kind: 'miss', tried: r, candidates: near }
}

// ---- no --resolve: the inventory ----
if (!ref) {
  if (asJson) {
    console.log(
      JSON.stringify(
        {
          screens: screenIds.map((id) => ({ id, path: `${SCREENS}/${id}.md`, components: rowsForScreen(id).map((r) => r.id) })),
          components: rows.map((r) => ({ id: r.id, name: r.name, status: r.status, contract: contractFile(r), consumedBy: r.consumedBy })),
        },
        null,
        2
      )
    )
    process.exit(0)
  }
  console.log(`UI 2.0 registry — ${rows.length} components, ${screenIds.length} screens\n`)
  console.log('SCREENS')
  for (const id of screenIds) console.log(`  ${id.padEnd(38)} ${rowsForScreen(id).length} components`)
  console.log('\nCOMPONENTS')
  for (const r of rows) console.log(`  ${r.id}  ${r.name.padEnd(26)} ${r.status.padEnd(18)} ${contractFile(r) ? 'own contract' : r.definedIn.slice(0, 44)}`)
  process.exit(0)
}

// ---- --resolve ----
const res = resolve(ref)

if (res.kind === 'ambiguous') {
  console.error(`Ambiguous ref "${res.tried}" — ${res.candidates.length} registry rows share that name:`)
  for (const c of res.candidates) console.error(`  ${c}`)
  console.error('Pass the C-### id instead.')
  if (asJson) console.log(JSON.stringify({ kind: 'ambiguous', ambiguous: true, tried: res.tried, candidates: res.candidates }, null, 2))
  process.exit(3)
}
if (res.kind === 'miss') {
  console.error(`No UI 2.0 screen or component matches "${res.tried}".`)
  if (res.candidates.length) {
    console.error('Nearest:')
    for (const c of res.candidates) console.error(`  ${c}`)
  }
  if (asJson) console.log(JSON.stringify({ kind: 'miss', tried: res.tried, candidates: res.candidates }, null, 2))
  process.exit(4)
}

const components = res.components.map((r) => ({
  id: r.id,
  name: r.name,
  status: r.status,
  platform: r.platform,
  figma: r.figma,
  contract: contractFile(r),
  consumedBy: r.consumedBy,
  dependencies: dependenciesOf(r),
}))

// A component ref carries its dependencies as scope; a screen ref already has them, being the
// whole screen. `built` is the build-side fact a caller needs: is there a preview to READ as the
// requirements? The fixture is the discriminator — a preview view is only capturable once
// capture/fixtures/ui2/<ID>.json exists — and the Swift file is the corroborating read. Matching
// on FILENAME alone is wrong: a glyph asset named `c034-…` is not a built component.
const previewDir = 'iphone/MakeReady/UI2Preview'
const fixtureDir = 'capture/fixtures/ui2'
const previewSources = existsSync(join(ROOT, previewDir))
  ? readdirSync(join(ROOT, previewDir))
      .filter((f) => f.endsWith('.swift'))
      .map((f) => ({ file: `${previewDir}/${f}`, text: read(join(ROOT, previewDir, f)) ?? '' }))
  : []
const built = (id) => {
  if (existsSync(join(ROOT, fixtureDir, `${id}.json`))) return true
  return previewSources.some((s) => new RegExp(`\\b${id}\\b`).test(s.text))
}
/** The row's OWN preview view, not a consumer that happens to mention it. `SearchField.swift`
 *  beats `ActionMenuRow.swift` even though both name C-034; failing a name match, only a file
 *  whose HEADER names the id counts, because that is where a preview declares what it is. */
const previewOf = (row) => {
  const want = `${row.name}.swift`.toLowerCase()
  const byName = previewSources.find((s) => basename(s.file).toLowerCase() === want)
  if (byName) return byName.file
  const re = new RegExp(`\\b${row.id}\\b`)
  const byHeader = previewSources.find((s) => re.test(s.text.split('\n').slice(0, 12).join('\n')))
  return byHeader?.file ?? null
}
for (const c of components) {
  c.built = built(c.id)
  c.preview = previewOf(c)
  c.fixture = existsSync(join(ROOT, fixtureDir, `${c.id}.json`)) ? `${fixtureDir}/${c.id}.json` : null
}

if (res.kind === 'component') {
  for (const dep of components[0].dependencies) {
    if (components.some((c) => c.id === dep)) continue
    const row = byId.get(dep)
    components.push({
      id: row.id,
      name: row.name,
      status: row.status,
      platform: row.platform,
      figma: row.figma,
      contract: contractFile(row),
      consumedBy: row.consumedBy,
      dependencies: [],
      built: built(row.id),
      preview: previewOf(row),
      fixture: existsSync(join(ROOT, fixtureDir, `${row.id}.json`)) ? `${fixtureDir}/${row.id}.json` : null,
      dependency: true,
    })
  }
}

const out = {
  kind: res.kind, // 'screen' | 'component' | 'set'
  title: res.title,
  ref,
  screen: res.screen ?? null,
  ambiguous: false,
  components,
  unbuilt: components.filter((c) => !c.built).map((c) => c.id),
  registry: REGISTRY,
}

if (asJson) {
  console.log(JSON.stringify(out, null, 2))
  process.exit(0)
}

console.log(`Scope: ${out.kind} ${out.title}${out.screen ? ` → ${out.screen}` : ''}`)
for (const c of out.components)
  console.log(
    `  ${c.id}  ${c.name.padEnd(24)} ${c.status.padEnd(18)} ${c.built ? 'built' : 'NOT built'}${c.dependency ? '  (dependency)' : ''}`
  )
if (out.unbuilt.length) console.log(`\nNot yet built as a preview: ${out.unbuilt.join(', ')}`)

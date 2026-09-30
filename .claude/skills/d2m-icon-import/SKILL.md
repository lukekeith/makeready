---
name: d2m-icon-import
description: Import many icons into the d2m icon library from ONE source — a folder or .svg file (imagesets and single-<svg> React/Vue components included), a Figma frame, a web page, a published npm icon set, or another d2m library — with a record of where each came from. `/d2m-icon-import <source>` gathers every candidate, dry-runs them through normalize_glyphs, shows one table and a rendered contact sheet, asks once, then mints each with put_glyph. Running the same import twice is a no-op.
argument-hint: <folder | file.svg | figma-url | https-url | npm:<package>[@<version>]/<name,…|*> | d2m:<project>/<era>[/<name,…>]> [--pick <glob>] [--tag <t>]… [--prefix <p>] [--yes] [--variant solid] [--project <slug>] [--era <key>]
---

# Icon import — $ARGUMENTS

Bring the icons at **$ARGUMENTS** into this project's icon library, each with a record of where it
came from. Every run is the same five steps: gather → dry-run → one table and one question → mint
→ report. The first bare argument is the source; the rest are flags. `--project <slug>` and
`--era <key>` override the scope this repo's `.mcp.json` pins. **Pass `--project` and `--era`
through to every tool call** — this session's scope. The `d2m:` reads in §1.5 are the only calls
that name another scope, and they name the SOURCE's.

Flags:

- `--pick <glob>[,<glob>]` keeps only the candidates whose proposed name matches (`*` any run of
  characters, `?` one), before the dry-run.
- `--tag <t>` (repeatable) is added to every minted icon through `put_glyph`'s `tags`.
- `--prefix <p>` puts `<p>-` in front of every proposed name, before the dry-run.
- `--yes` skips the question only when every row is `new`; otherwise it is ignored.
- `--variant solid` picks heroicons' solid set (npm only).

## Hard rules (re-read before EVERY phase)

- **Writes: `put_glyph`, one call per row, and only after phase 3's answer.** `tag_glyph` only on
  an existing glyph named in a `replace:` answer. Never `rename_glyph`, `merge_glyph`,
  `strike_glyph` or `use_glyph`.
- **The confirm comes before any mint.** Nothing is written until phase 3 has its answer, or
  `--yes` applies to an all-new batch.
- **`put_glyph` never names the SOURCE's project or era** (the `d2m:` read's). Like every call, it
  carries this run's `--project`/`--era` when they were given; only §1.5's reads name the SOURCE's
  project and era.
- **One temp directory per run.** Phase 0 makes it with `mktemp -d` and prints its absolute path;
  every fetched, extracted or exported SVG is a file in it, handed to the tools by absolute `path`.
  **`$WORK` does not survive between tool calls — every command that touches it starts
  `WORK=<the printed path>;` in that same call.** Never rely on an earlier command's `WORK=`
  assignment still being set. Delete it with `rm -rf "$WORK"` at the end of phase 5, on every
  failure before the `✗` line, and on **Cancel**. Nothing is written into the repo;
  `render_glyph`'s sheets stay in the OS temp directory.
- **Fetch only `https://`, and never a host that resolves to a loopback or private address**
  (§1.4's check, before every page, every linked `.svg`, and every redirect hop). Never WebFetch.
- **Refusals are reported verbatim**, against their row: the normaliser's, the converter's,
  `put_glyph`'s.
- **Ending failed** means: print the phase's exit checklist, run `rm -rf "$WORK"`, and make
  `✗ <reason>` the last line.

**At the end of every phase, print that phase's exit checklist with ✓/✗ per item.**

## 0. Load context

1. `project_info()`. **State the project slug and era key in your first report line.** Keep the
   project slug for the report's link.
2. In a d2m run or a session? `echo "${D2M_WORK_ID:-}"` prints an id inside a run and nothing in a
   session. Phase 3's question and §1.4's browser fallback depend on it.
3. `WORK=$(mktemp -d "${TMPDIR:-/tmp}/d2m-icon-import.XXXXXX")` — print the path. **Every later
   command that touches `$WORK` re-declares it first, in that same tool call**
   (`WORK=<the printed path>; …`): a tool call is a fresh shell, and shell variables do not
   survive between calls.
4. Read the flags. **`--prefix <p>` must itself be an icon name** — lowercase kebab-case, starting
   with a letter (`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`). If it is not, end failed: "`--prefix <p>` is
   not an icon name — lowercase kebab-case, starting with a letter".

**Exit checklist 0:** project + era stated ✓ · run or session recorded ✓ · `$WORK` made ✓ · flags
read, `--prefix` valid ✓

## 1. Gather

**Which source.** Test the first bare argument in this order; the first match wins:

1. starts `d2m:` → **project** (§1.5)
2. starts `npm:` → **npm** (§1.3)
3. a URL whose host is `figma.com` or `www.figma.com` → **figma** (§1.2)
4. starts `http://` or `https://` → **web** (§1.4)
5. anything else → **path** (§1.1), resolved against the session's working directory

One source per run. A path that does not exist, or a form none of these fit, ends failed with the
accepted forms: "a folder or .svg file · a Figma frame URL · an https:// page ·
npm:<package>/<names> · d2m:<project>/<era>".

**Every candidate** leaves this phase as one row: a `key` — a purely numeric one, zero-padded to
four digits (`0001`, `0002`, …) — the absolute `path` of
its SVG file, a proposed name, and what `put_glyph` records — `source`, `sourceRef`, `license`
(plus `figmaNodeId`/`figmaFileKey` for Figma, and `tags`/`notes` for a d2m copy). Rows a source
refuses or skips are kept for the table and the report. **Every file this run writes for a
candidate is `$WORK/<key>.svg`**: an all-digit file name proposes no icon name, so an unnamed
candidate comes back `unnamed` — never named after its temp file.

**Proposed names.** Split camelCase and PascalCase at each capital (`ArrowLeftIcon` → `Arrow Left
Icon`), drop a leading `Svg` word (SVGR's prefix), lowercase, drop `.svg`, turn every run of other
characters into `-`, then drop a leading component prefix (`c072-`, `c-021-`) and every `icon` or
`glyph` segment. A result that is not an icon name leaves the row unnamed: it goes to the dry-run
with no `name`, and comes back `unnamed`.

### 1.1 A path

- `~` is your home directory. A `.zip`, `.tar` or `.tgz` argument ends failed: "unpack it first".
- **A file** is that one `.svg`; any other file ends failed with the accepted forms.
- **A folder** is walked. `find -H` follows the argument itself if it is a symlink, and no
  symlink below it:

  ```sh
  find -H "<dir>" \( -name node_modules -o -name .git -o -name build -o -name dist -o -name DerivedData -o -name Pods \) -prune -o -type f \( -name '*.svg' -o -name '*.pdf' -o -name '*.jsx' -o -name '*.tsx' -o -name '*.vue' \) -print | head -n 5001
  ```

  5,001 lines means more than 5,000 files: end failed with "more than 5,000 files under <dir> —
  narrow the path".
- **Each `*.svg`** outside an imageset is a candidate, named from its file name.
- **Each `*.imageset` folder** holding an `.svg` is ONE candidate, named from the imageset's name
  without a leading `c###-`. An imageset holding only a `.pdf` is refused: "PDF artwork — export
  SVG". A `.pdf` outside an imageset is ignored.
- **Each `.jsx`, `.tsx` or `.vue` file** goes through the converter below, which writes the ONE
  `<svg>` element the file exports as SVG: camelCase attributes become kebab-case, `className` is
  dropped, a literal `{2}` or `{"x"}` keeps its value, every other `{…}` expression attribute is
  dropped, `{...props}` is removed, and any other `{…}` left inside the `<svg>` (a conditional, a
  loop, a computed child) refuses the file. Name the candidate from the exported component's name
  (`export default function <Name>`, `export const <Name> =`, `const <Name> = …; export default
  <Name>`), else from the file name.

Write this file to `$WORK/jsx2svg.mjs` exactly as it is:

```js
// jsx2svg.mjs — one component file in, its ONE <svg> out as SVG text (icon-import D2).
// Usage: node jsx2svg.mjs <component file> <out.svg>
// Prints one line: {"ok":true} (out.svg written) · {"refused":"<why>"} · {"nosvg":true}
import fs from 'node:fs';
const [file, out] = process.argv.slice(2);
const src = fs.readFileSync(file, 'utf8');
const say = (o) => { console.log(JSON.stringify(o)); process.exit(0); };
const opens = [...src.matchAll(/<svg[\s>/]/g)];
if (opens.length === 0) say({ nosvg: true });
if (opens.length > 1) say({ refused: 'more than one <svg> in the file — export each icon as SVG' });
const start = opens[0].index;
const end = src.indexOf('</svg>', start);
if (end === -1) say({ refused: 'no closing </svg> — export it as SVG' });
let svg = src.slice(start, end + '</svg>'.length);
if (/\sv-(if|else-if|else|for|show)\b/.test(svg)) say({ refused: 'conditional JSX — export it as SVG' });
svg = svg.replace(/\s(?::|@|v-)[\w:.-]*(?:=(?:"[^"]*"|'[^']*'))?/g, '');             // Vue bindings and directives
svg = svg.replace(/\{\s*\.\.\.[^{}]*\}/g, '');                                         // {...props}
svg = svg.replace(/\s([A-Za-z][\w:.-]*)=\{\s*(-?\d+(?:\.\d+)?)\s*\}/g, ' $1="$2"');     // a literal number keeps its value
svg = svg.replace(/\s([A-Za-z][\w:.-]*)=\{\s*(["'])([^"'{}]*)\2\s*\}/g, ' $1="$3"');    // a literal string keeps its value
svg = svg.replace(/\s[A-Za-z][\w:.-]*=\{\{[^{}]*\}\}/g, '');                            // style={{ … }}
svg = svg.replace(/\s[A-Za-z][\w:.-]*=\{[^{}]*\}/g, '');                                // any other {…} expression attribute
if (/[{}]/.test(svg)) say({ refused: 'conditional JSX — export it as SVG' });
svg = svg.replace(/\s(?:className|class)=(?:"[^"]*"|'[^']*')/g, '');
const KEEP = new Set(['viewBox', 'preserveAspectRatio', 'gradientUnits', 'gradientTransform', 'clipPathUnits', 'spreadMethod']);
const RENAME = { xlinkHref: 'xlink:href', xmlnsXlink: 'xmlns:xlink', xmlSpace: 'xml:space' };
svg = svg.replace(/(\s)([a-z][a-z0-9]*[A-Z][A-Za-z0-9]*)=/g, (m, sp, name) =>
  (KEEP.has(name) ? m : `${sp}${RENAME[name] ?? name.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}=`));
if (!/^<svg[^>]*\sxmlns=/.test(svg)) svg = svg.replace(/^<svg/, '<svg xmlns="http://www.w3.org/2000/svg"');
fs.writeFileSync(out, svg);
say({ ok: true });
```

Then, per component file: `node "$WORK/jsx2svg.mjs" "<file>" "$WORK/<key>.svg"`. It prints one
line of JSON:

- `{"ok":true}` — `$WORK/<key>.svg` holds the SVG: a candidate.
- `{"refused":"…"}` — a refused row, with that sentence.
- `{"nosvg":true}` — the file draws its icon through a helper (`createLucideIcon`, `GenIcon`,
  `createSvgIcon`) and holds no literal `<svg>`. **Count these files; never skip them silently.**
  The report says: "<N> component files had no literal `<svg>` — import that package with `npm:`
  instead".

Every path row: `source: "file"`, `sourceRef` = the file's absolute path (the imageset folder's,
for an imageset), no `license`.

### 1.2 A Figma frame

1. Parse the file key (the path segment after `/design/` or `/file/`) and the node id (`node-id`,
   its `-` turned into `:`). No `node-id` ends failed: "the URL names no node — give a frame,
   group, section, component set or page URL".
2. **Rung 1 — ONE `use_figma` script for every child**. Load the `figma-use` skill first if this
   session has it. The script finds the candidates with THIS skill's node-type list — a
   `VECTOR`, `BOOLEAN_OPERATION`, `COMPONENT` or `INSTANCE`, or a `FRAME`/`GROUP` whose
   descendants are only vector shapes — among the node's direct children (or the node itself,
   when it is one icon), and exports each with `exportAsync` `SVG_STRING`. It is not
   `/d2m-icon-intake`'s single-node count, which does not count bare vectors.

   ```js
   const root = await figma.getNodeByIdAsync('<nodeId>');
   if (!root) return { missing: true };
   if (root.type === 'PAGE') await root.loadAsync();
   const START = 0, END = Infinity;
   const SHAPES = ['VECTOR', 'BOOLEAN_OPERATION', 'ELLIPSE', 'RECTANGLE', 'LINE', 'STAR', 'POLYGON'];
   const onlyVectors = (n) => 'children' in n && n.children.length > 0
     && n.children.every((c) => SHAPES.includes(c.type) || ((c.type === 'FRAME' || c.type === 'GROUP') && onlyVectors(c)));
   const isIcon = (n) => ['VECTOR', 'BOOLEAN_OPERATION', 'COMPONENT', 'INSTANCE'].includes(n.type)
     || ((n.type === 'FRAME' || n.type === 'GROUP') && onlyVectors(n));
   const nameOf = (n) => (n.type === 'COMPONENT' && n.parent && n.parent.type === 'COMPONENT_SET' && n.variantProperties
     ? Object.values(n.variantProperties).join('-') : n.name);
   const all = isIcon(root) ? [root] : ('children' in root ? root.children.filter((c) => c.visible !== false && isIcon(c)) : []);
   const items = [];
   for (const n of all.slice(START, END)) {
     try { items.push({ id: n.id, name: nameOf(n), svg: await n.exportAsync({ format: 'SVG_STRING' }) }); }
     catch (e) { items.push({ id: n.id, name: nameOf(n), svg: null, error: String((e && e.message) || e) }); }
   }
   return { layer: root.name, type: root.type, total: all.length, items };
   ```

   If the answer is cut off or the call times out, run the same script again in ranges of 50
   (`START = 0, END = 50`, then `50, 100`, …) until `total` is covered.
   - `missing: true` ends failed: "node <nodeId> not found in <fileKey>".
   - `total: 0` ends failed: "no icons under <layer> — each icon is a component, an instance, a
     vector, a boolean or a group of vectors".
   - A node that is itself one icon answers one item: a one-row table.
3. **An item whose `svg` is null** goes down the ladder alone. Rung 2: the Figma connector's
   `download_assets` with `fileKey`, `nodeId` = the item's `id` and `defaultFormat: "svg"`; it
   answers `{"export":{"url":…}}` — `curl -sL -o "$WORK/<key>.svg" "<url>"`. Rung 3, only when
   `$FIGMA_TOKEN` is set: `curl -sS -H "X-Figma-Token: $FIGMA_TOKEN"
   "https://api.figma.com/v1/images/<fileKey>?ids=<id>&format=svg"`, then curl the URL it answers.
   Never print the token. No rung answered: a refused row, "no SVG export for <id> — <each rung
   and why>".
4. Write each `svg` to `$WORK/<key>.svg`. The name is the item's `name` (a component set's
   variants arrive as their values joined by `-`).
5. Every Figma row: `source: "figma"`, `figmaNodeId` = the item's `id`, `figmaFileKey` = the file
   key, `sourceRef` = the URL as given, no `license`.

`/d2m-icon-intake` and the Icons page's Figma door stay one node, one icon; this section is the
only many-icon Figma path.

### 1.3 An npm package

Form: `npm:<package>[@<version>]/<name>[,<name>…]`, or `/*` for a whole set. A scoped package keeps
its scope: `npm:@tabler/icons@3/bell` is package `@tabler/icons`, version `3`, name `bell`.

1. **The exact version:** `curl -sS "https://data.jsdelivr.com/v1/packages/npm/<package>/resolved?specifier=<version, or latest>"`
   answers `{"version":"<exact>"}`. A null version ends failed: "npm package
   <package>@<version> not found".
2. **The licence:** `curl -sS "https://cdn.jsdelivr.net/npm/<package>@<exact>/package.json"`.
   Take `license` when it is a string, else its object's `type`, else the first `licenses[]`
   entry's `type`; cut to 128 characters. None: no licence.
3. **Where the icons are** (`<n>` is the icon name):

   | Package | Path |
   |---|---|
   | `lucide-static` | `icons/<n>.svg` |
   | `heroicons` | `24/outline/<n>.svg` — `--variant solid` → `24/solid/<n>.svg` |
   | `@tabler/icons` | `icons/outline/<n>.svg` |
   | `@phosphor-icons/core` | `assets/regular/<n>.svg` |
   | `@material-symbols/svg-400` | `outlined/<n>.svg` |

   heroicons' `20/solid` and `16/solid` sets are out of scope: they are not drawn on a 24 grid.
   **A known layout that answers 404 at the resolved version falls back to a flat
   `icons/<n>.svg`** (layouts move between majors). Any other package: list its files with
   `curl -sS "https://data.jsdelivr.com/v1/packages/npm/<package>@<exact>?structure=flat"`, show the
   directories that hold `.svg` files with their counts, and ask which one (phase 3's rule for
   asking: `await_answers` in a run, directly in a session).
4. **`/*`** is every `.svg` in that directory, from the same listing. **Over 500 icons:** ask for
   a narrower list (names or `--pick`) before anything is fetched.
5. **Fetch each:** `curl -sSf -o "$WORK/<key>.svg" "https://cdn.jsdelivr.net/npm/<package>@<exact>/<path>"`.
   A 404 on a named icon is a refused row: "no <n> in <package>@<exact>".
6. Every npm row: name `<n>`, `source: "npm"`, `sourceRef` = `npm:<package>@<exact>/<n>`,
   `license` from step 2.

### 1.4 A web page

1. **The fetch rule (D16).** Before fetching the page, and before fetching every `.svg` it links,
   check the URL. It prints `ok`, or `refuse: …` — a refused page ends failed with that sentence,
   a refused linked file is a refused row:

   ```sh
   node -e '
   const dns = require("node:dns/promises");
   const u = new URL(process.argv[1]);
   if (u.protocol !== "https:") { console.log("refuse: only https:// targets are fetched, not " + u.protocol); process.exit(0); }
   const V4 = /^(0\.|10\.|127\.|169\.254\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.)/;
   const V6 = /^(::1?$|f[cd]|fe[89ab]|::ffff:)/i;
   dns.lookup(u.hostname, { all: true }).then((all) => {
     const bad = all.find(({ address }) => V4.test(address) || V6.test(address));
     console.log(bad ? "refuse: " + u.hostname + " resolves to " + bad.address + ", a loopback or private address" : "ok");
   }, (e) => console.log("refuse: " + u.hostname + " does not resolve (" + e.code + ")"));
   ' "<url>"
   ```

2. **The raw page, every redirect hop checked too.** `curl` never follows a redirect on its own —
   `--max-redirs 0` — because a 3xx can point anywhere, including a loopback or private address
   step 1 would have refused:

   ```sh
   WORK=<the printed path>; curl -sS -D "$WORK/h.txt" -o "$WORK/page.html" -w '%{http_code}' \
     --proto '=https' --proto-redir '=https' --max-redirs 0 --max-time 30 "<url>"
   ```

   **A `3xx` status:** read `Location` from `$WORK/h.txt`, resolve it against the URL just
   fetched, and run step 1's check on THAT url before touching it — a redirect target is exactly
   as unchecked as the original URL until it has. Passing, fetch it the same way. **Up to 3 hops
   total; a 4th `3xx`, or any hop's check answering `refuse: …`, ends the fetch refused with that
   hop's reason** (the page ends failed; a linked file is a refused row).
3. **Candidates in the raw HTML:** each inline `<svg>…</svg>`; each `<symbol>` of an inline sprite,
   wrapped as `<svg xmlns="http://www.w3.org/2000/svg" viewBox="<the symbol's viewBox>">…</svg>`;
   each `<img src>` or `<a href>` whose URL path ends `.svg`, resolved against the page URL,
   checked with step 1, and fetched by step 2's redirect-checked rule into `$WORK/<key>.svg`.
   Write every inline one to `$WORK/<key>.svg`.
4. **Names**, the first that gives an icon name: `aria-label`, the `<title>`, `id`, the file name,
   then `web-icon-<n>`.
5. **Not an icon (size):** skip a candidate whose width or height (the attributes, else the
   viewBox) is under 8, or whose `d` attributes hold more than 400 path commands (the letters
   `MLHVCSQTAZ`, either case). Count them for the report.
6. Every web row: `source: "web"`, `sourceRef` = the page URL, plus `#<id>` when the candidate
   has an id; no `license`.
7. **Nothing found in the raw HTML:**
   - **In a d2m run:** end failed with "nothing found in the raw HTML — this page renders its
     icons with JavaScript; run the import in a terminal session". Never open a browser from a run.
   - **In a session:** use claude-in-chrome — `mcp__claude-in-chrome__navigate` to the page, then
     `mcp__claude-in-chrome__javascript_tool` returning every `svg` element's `outerHTML`,
     `aria-label`, `id` and on-screen size — and treat each as step 3's inline `<svg>`. It sees
     what the signed-in browser sees; nothing is done to get past a login.

### 1.5 Another d2m library

Form: `d2m:<project>/<era>[/<name>[,<name>…]]`.

1. `list_glyphs()`, called with its `project` scope override set to `<project>` and its `era`
   override set to `<era>` — the SOURCE. It lists minted, live icons only, so a pending or struck
   icon is never offered. With names, keep those; a name it does not list is a refused row: "no
   live <name> in <project>/<era>".
2. Per icon, `get_glyph(name: "<name>")` with the same SOURCE overrides; write its `svg` to
   `$WORK/<key>.svg`.
3. Every d2m row: its own name, `source: "project"`, `sourceRef` = `d2m:<project>/<era>/<name>`,
   `license` = its `license`, and its `tags` and `notes` copied. Its usages are not copied.

**Then `--pick`, then `--prefix`:** keep the rows whose proposed name matches a `--pick` glob; then
prepend `<p>-` to every proposed name. Both happen here, before the dry-run, so the dry-run checks
the names that will be minted.

**Exit checklist 1:** source detected ✓ · every candidate an SVG file with a proposed name and its
provenance ✓ · refused and skipped rows kept ✓ · `--pick` then `--prefix` applied ✓

## 2. Dry-run

`normalize_glyphs(items: [{ key, path, name }])`, at most 500 items per call (chunk a bigger
batch). `name` is the proposed name; leave it out for an unnamed row. Each item answers its
`status` — `new` · `duplicate` · `unnamed` · `name-taken` · `multicolour` · `refused` — with
`matches` (the live icon, `reserved`, or the earlier key in the batch), `rejected` and `colors`.
Keep the answer on its row. Nothing is written.

**Nothing to import:** 0 `new` and 0 `multicolour` rows → skip phases 3 and 4, and report
"nothing to import" with the table's counts; running the same import twice lands here.

**Exit checklist 2:** every row dry-run ✓ · nothing written ✓ · nothing-to-import checked ✓

## 3. Confirm

1. **The table.** One table, grouped in this order, each group headed with its count: **new** ·
   **multi-colour** · **name taken** · **duplicate** · **unnamed** · **refused** (the dry-run's
   and §1's). Columns: key · proposed name · status · `matches` or the reason · colours. Then one
   line for the not-an-icon (size) count and one for the no-literal-`<svg>` count.
2. **The sheets.** `render_glyph(svgs: [{ label, path }])` for the **new** and **multi-colour**
   rows, labelled with the proposed name (the key when unnamed) — **48 icons per call**. Run
   `open "<file>"` on each sheet's `file` in turn; **above 4 sheets, print the paths instead of
   opening them**.
3. **`--yes`** skips the question when every row is `new`. Otherwise it is ignored.
4. **ONE question, three options:** **Import the N new** (N is the count of new rows;
   recommended) · **Choose** · **Cancel**.
   - **In a d2m run** (phase 0 found an id):
     `await_answers(subject: "icons", questions: [{ question, options, recommended }])` with
     `recommended` 0, then END YOUR TURN. The owner answers on this run's card in the terminal,
     and the run resumes with the answer.
   - **In a session:** ask the user directly and wait.

   **Cancel** ends the run with nothing minted — `rm -rf "$WORK"` before ending, the same cleanup
   as a failure.
5. **Choose** asks ONE follow-up the same way, answered in free text — tokens separated by spaces
   or commas:
   - `<name>` of a **new** row — leave it out;
   - `<name>` of a **multi-colour** row — import it too (the tint flattens it to one colour);
   - `old=new` — rename a row (`old` is its proposed name);
   - `<key>=<name>` — name an **unnamed** row (an icon name always starts with a letter, so an
     all-digit left side is a key, and any other left side is a proposed name);
   - `replace:<name>` — give a **name taken** row's art to the live icon of that name, which
     keeps its usages and call sites. **Offered only when the row's `matches` equals its proposed
     name**. A clash with another icon's Swift case, a reserved name or another row of this batch
     offers only a rename or leaving it out.
6. **Rows renamed or named in Choose are dry-run again** — `normalize_glyphs(items: [{ key, path, name }])`
   for just those rows — before any mint. A row that comes back anything but `new` (or
   `multicolour`, for a multi-colour row chosen in) is left out, with its new status in the report.

**Exit checklist 3:** table printed with counts ✓ · sheets rendered and opened, or listed ✓ · one
answer, or `--yes` on an all-new batch ✓ · Choose's renames dry-run again ✓

## 4. Mint

For each chosen row, one at a time:

`put_glyph(name: "<name>", svg: "<the text of its file>", source: "<source>", sourceRef: "<sourceRef>", license: "<license>", tags: [<its tags>])`

- A Figma row also passes `figmaNodeId` and `figmaFileKey`; a d2m copy also passes `notes` and its
  source's tags; every `--tag` joins every row's `tags`. Leave out `sourceRef` or `license` when
  the row has none.
- A `replace:<name>` row also passes `replace: true`: that icon keeps its name, usages and call
  sites, and its tags gain the new ones.

Read each answer:

- the glyph → **minted**;
- a `note` saying `already in the library as <x>` → **skipped (duplicate)**; nothing was written;
- a refusal (`put_glyph failed: …` — e.g. a 409 because the library changed since the dry-run) →
  **failed**, with the sentence verbatim against its row, and **the run carries on** with the
  next row.

Two imports can interleave: a run parked on its question does not hold the `icons` subject, so a
name can be taken between the dry-run and the mint. The per-row answer is what covers that.

**Exit checklist 4:** one `put_glyph` per chosen row ✓ · every answer recorded minted, skipped or
failed ✓ · a failed row did not stop the run ✓

## 5. Report

Print these lines, then `WORK=<the printed path>; rm -rf "$WORK"` (re-declared in that same call),
then stop:

- **project + era**, first;
- **source** — the argument and the kind detected;
- **minted · skipped · failed** — the three counts, then each failed row with its reason;
- **left out** — rows left out in Choose, refused rows with their reasons, the not-an-icon (size)
  count, and "<N> component files had no literal `<svg>` — import that package with `npm:`
  instead" when N > 0;
- **sheets** — their temp paths;
- **next** — `/<slug>/icons` to see them; `/d2m-icon-tag <name> +<tag>` to tag more.

**Exit checklist 5:** report printed ✓ · `$WORK` deleted ✓ · nothing written but the `put_glyph`
calls ✓

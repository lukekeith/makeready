# Screen notes

One append-only markdown file per screen, named `<screen-id>.md`. Created the first time a note is
written, so an empty directory means "nobody has written one yet" — not a missing feature.

**Notes are normative.** They say what a screen is *for* and how it should behave, which neither
Figma nor the contract doc can say. `/ui2-component-build` honours them, and
`/ui2-component-update` verifies a built preview against spec **plus** notes. A newer note
supersedes an older one, and a note supersedes the spec — every override is reported as drift,
never written back into these docs automatically
(`docs/features/ui2-component-notes/01-architecture.md` D3).

**Format** — `docs/features/ui2-component-notes/03-data-and-api.md` §1.1, in short:

```markdown
# <id> <Name> — notes

<this preamble>

## 2026-09-11T14:32:05.412Z

Plain text. Blank lines are preserved and markdown is NOT rendered — a note is read as
written. `@C-019` and `@home-dashboard` are canonical mention tokens, resolved to current
display names at read time so a rename never rots a note.
```

- Headings are `##` + an ISO 8601 UTC instant with milliseconds. That instant is the note's
  id, its sort key, and what "newer" means. A `##` that is not an instant is body text.
- Oldest first in the file (appending is a pure append); the browser displays newest first.
- Written by the capture browser's Screen tab. Hand-edit only to fix a typo — there is no edit or
  delete, because correcting a note means writing a newer one.
- Read them without the server: `node capture/lib/ui2-notes.mjs read <target>`.

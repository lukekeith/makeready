# 06 — iPhone

**Not affected** (no code change in `/iphone` ships with this feature). Two read-only
dependencies, for the record:

- `iphone/MakeReady/Components/` is the tree and scope source of truth (01 D1): the capture
  backend walks its directories and `*.swift` basenames to build the fs index (03 §1).
  Moving/renaming component files reorganizes the browser — that is the intended workflow,
  not an impact of this build.
- `iphone/MakeReadyCaptureTests/ViewRegistry.swift` is parsed (regex for
  `component.<Name>` cases, mtime-cached) for wiring status (01 D16). It is not edited.

At **runtime** the `/component-resolve` command edits Swift component files to address the
user's comments — that is the command doing the user's bidding on their annotations (07 §6),
equivalent to the user editing the app, and is not part of this feature's build scope. Wiring
new components into the harness stays separate `/capture-add` work (01 §Out of scope).

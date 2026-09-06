# UI2Preview — preview-only 2.0 component views

**Preview only.** Every file in this folder is built by `/ui2-component-build <C-###>` from a
frozen contract under `docs/ui2/design-system/components/`, so it can be rendered in the
simulator and diffed against its Figma snapshot in the capture browser. Nothing here is wired
into the app: no screen, route, tab, flag or `NavigationCoordinator` case references it
(`docs/ui2/preview-build.md` §3 rule 1). It lives in the `MakeReady` target only because
`MakeReadyCaptureTests/ViewRegistry.swift` reaches views through `@testable import MakeReady`.

`UI2PreviewTokens.swift` is **generated** from `docs/ui2/design-system/tokens.md` by
`node capture/lib/ui2-tokens.mjs` — never hand-edited.

**Promotion.** The `ui2-shell` suite decides the real 2.0 tree path, module boundary and
flag; at that point these files move into that tree and this folder goes away
(`docs/ui2/preview-build.md` §7). Until then they exist to be looked at and diffed.

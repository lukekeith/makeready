# UI2Preview — preview-only 2.0 component views

**Its own Swift module.** These files are **not** in the `MakeReady` app target. They compile
into the `UI2Preview` framework target, which imports SwiftUI and nothing else. That is why
the types here are named plainly — `TextInput`, `PageHeader` — even though `MakeReady/` still
declares 1.0 types with those names: a folder is not a namespace in Swift, a module is
(`docs/ui2/preview-build.md` §2). Membership is not implied by the folder; it is synced into
the pbxproj by `ruby iphone/scripts/ui2-preview-sync.rb`, which every
`/ui2-component-build` run calls.

The sources sit under `MakeReady/` on disk only for path stability (and so SwiftLint's
`included: MakeReady` keeps covering them).

**Preview only.** Every file here is built by `/ui2-component-build <C-###>` from a frozen
contract under `docs/ui2/design-system/components/`, so it can be rendered in the simulator and
diffed against its Figma snapshot in the capture browser. Nothing here is wired into the app:
no screen, route, tab, flag or `NavigationCoordinator` case references it
(`docs/ui2/preview-build.md` §3 rule 1). The one consumer is
`MakeReadyCaptureTests/ViewRegistry.swift`, which reaches these types through
`@testable import UI2Preview` and module-qualifies each one.

`Tokens.swift` is **generated** from `docs/ui2/design-system/tokens.md` by
`node capture/lib/ui2-tokens.mjs` — never hand-edited.

**Promotion.** The `ui2-shell` suite decides the real 2.0 tree path and whether this module
survives as a module; either way the files move and **no type is renamed**
(`docs/ui2/preview-build.md` §7). Until then they exist to be looked at and diffed.

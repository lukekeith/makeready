# MakeReadyUI — the UI 2.0 views

**Its own Swift module.** These files are **not** in the `MakeReady` app target. They compile
into the `MakeReadyUI` framework target, which imports SwiftUI and nothing else. That is why
the types here are named plainly — `TextInput`, `PageHeader` — even though `MakeReady/` still
declares 1.0 types with those names: a folder is not a namespace in Swift, a module is
(`docs/ui2/preview-build.md` §2). Membership is not implied by the folder; it is synced into
the pbxproj by `ruby iphone/scripts/makereadyui-sync.rb`, which every
`/ui2-component-build` run calls.

The sources sit in `iphone/MakeReadyUI/`, beside `iphone/MakeReady/`.

**These views ship.** d2m builds them from contracts; the app wires them from `iphone/MakeReady/UI2/` containers (docs/features/ui2-shell SPEC D2, D29). Never hand-wire a file here — a d2m rebuild overwrites it.

`Tokens.swift` is **generated** by d2m from its token store (`set_color_token` changes a value)
— never hand-edited.

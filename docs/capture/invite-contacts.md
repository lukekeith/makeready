# Invite Contacts

**iPhone source:** `iphone/MakeReady/Pages/View/Member/InviteContactsPage.swift`
**Type:** screen (presented modally)
**Screen states:** no-permission (permission request) / empty (no contacts match) / populated (contact list)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `iconTitleLink` | Header: "Invite contacts", left `xmark` icon, right "Done" link. Used in the permissioned path's `header`. |
| `SearchableList` | default (with `showAlphabetScrubber: true`, `sectionKeyPath: \.fullName`) | Wraps the searchable, A–Z-sectioned contact list; takes the `header` closure (`PageTitle`) and a row builder. |
| `SearchField` | default | Rendered internally by `SearchableList` as the search bar. |
| `SectionedTableView` | default | Rendered internally by `SearchableList` when alphabet scrubbing is on (hosts the `AlphabetScrubber`). |
| `AlphabetScrubber` | default | Provided by `SectionedTableView` for A–Z jump navigation. |
| `CardContact` | default + trailing-content (`showBackground: false`) | Each contact row. With a phone number it embeds an `ActionButton` trailing slot; without one it uses the no-trailing-content init. |
| `ActionButton` | `.purple` | "Invite" button in the trailing slot of phone-having contacts. |
| `BoxButton` | `variant: .primary`, `size: .lg` | "Allow Access" in the permission-request view. |

## Notes
- Two top-level states gate the body: when `contactsManager.hasPermission == false`, a custom `permissionRequestView` (SF Symbol + copy + `BoxButton`) shows; otherwise the `SearchableList`.
- `CardContact` is used with `showBackground: false` here (transparent row) — distinct from `search-contacts.md` which uses the default background.
- The permission view's SF Symbol + text block are raw SwiftUI, not inventory components.
- The two `#Preview` blocks duplicate the same component set with mock contacts (one starts in the permission state).

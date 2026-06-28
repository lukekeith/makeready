# Search Contacts

**iPhone source:** `iphone/MakeReady/Pages/View/Member/SearchContactsPage.swift`
**Type:** screen (pushed; has a back chevron)
**Screen states:** empty (no contacts match) / populated (contact list)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SearchableList` | default (with `showAlphabetScrubber: true`, `sectionKeyPath: \.fullName`) | Wraps the searchable, A–Z-sectioned contact list; takes a custom `header` closure and a row builder. |
| `SearchField` | default | Rendered internally by `SearchableList` as the search bar. |
| `SectionedTableView` | default | Rendered internally by `SearchableList` when alphabet scrubbing is on (hosts the `AlphabetScrubber`). |
| `AlphabetScrubber` | default | Provided by `SectionedTableView` for A–Z jump navigation. |
| `CardContact` | default (default background, trailing-content init) | Each contact row, with the brand-default card background (no `showBackground: false`). |
| `ActionButton` | `.purple` | "Invite" button in the trailing slot — only for contacts with a phone number; otherwise `EmptyView()`. |

## Notes
- Header here is a **hand-rolled `HStack`** (back `chevron.left`, centered "Invite contacts" title, "Done" link), **not** `PageTitle` — unlike `invite-contacts.md` which uses `PageTitle.iconTitleLink`. Flag for parity / possible refactor to `PageTitle`.
- `CardContact` uses its **default background** here (the trailing-content init without `showBackground: false`), differing from the transparent rows on the Invite Contacts screen.
- No permission-gating state on this screen (it assumes contacts are available).

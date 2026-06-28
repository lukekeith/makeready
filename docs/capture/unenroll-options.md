# Unenroll Options

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/Enrollment/UnenrollOptionsModal.swift`
**Type:** overlay/modal (presented via `overlayManager`)
**Screen states:** loading ("Checking enrollment status…") / options (context-aware) / confirm / error (retry). Options phase branches on `canFullyUnenroll`: full-removal path vs cancel-future path with member-data warning + disabled full-removal explanation.

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `.iconTitle` (leftIcon `xmark` on options/error; leftIcon `chevron.left` on confirm) | Header; titles "Unenroll" / "Confirm". |
| `CachedAsyncImage` | size 56, `fallbackIcon: "book.fill"` | Program thumbnail in the program header (utility image view, not in the card inventory). |

## Notes
- This modal is almost entirely bespoke layout. The info banner, option cards, confirm icon/buttons, and "Never mind" link are all local private helpers (`infoBanner`, `optionCard`, `programHeader`, `confirmContent`), not shared components.
- Two `UnenrollOption` outcomes: `.fullRemoval` (only when no member responses) and `.cancelFuture` (when some lessons have member data). The destructive vs warning color (`#ff4444` / `#ffaa00`) and copy switch on the selected option.
- Confirm buttons are raw `Button`s, not `BoxButton`/`ActionButton`.
- No `DialogOverlay`/`ConfirmationOverlay` is used here — the confirm step is a custom phase within this modal. (The separate processing overlay after confirming is owned by the parent list page via `UnenrollConfirmation`; see `enrollments-list.md`.)

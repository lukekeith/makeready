# FilterRail — the one filter-chip row

Owner ruling 2026-11-01: "all the filter buttons on all the pages with search and filters need to be
standardized in the way they work. They are supposed to all support left/right swiping. The
enrollment page's filters are accurate, the rest seem to be off." Then: one shared component, not a
copy per page.

## The standard (normative)

The behaviour is `EnrollmentsHomeScreen.chipRow` (`iphone/MakeReadyUI/Screens/Enrollments/EnrollmentsHomeScreen.swift`)
and `InvitesHomeScreen.chipRow`, which match each other:

1. **One horizontal row of C-035 FilterChip**, gap `space-element-gap` (8), chips at their intrinsic
   24 pt height, each hugging its label. Labels never truncate or squeeze to fit.
2. **It always swipes left and right**, as `HorizontalRail` (MakeReadyUI/HorizontalScrolling.swift),
   never a raw `ScrollView(.horizontal)` and never a plain `HStack`. It swipes even when every chip
   fits (the rail just has nothing to move), so a page whose chips grow (several picks, long names)
   never clips or squeezes.
3. **Full bleed.** The rail spans the full screen width, edge to edge, outside any page side padding.
   The `space-page-margin` (16) leading and trailing inset is inside the scroll content, so at rest
   the first chip sits 16 from the left edge, and when scrolled the chips pass under both screen edges.
4. **No scroll indicators.** No edge fade, no background, no divider.
5. **Vertical rhythm stays with the page.** The rail adds no vertical padding of its own; each page
   keeps its current gap from the search field and to the content below.
6. A vertical swipe that starts on the rail scrolls the page (HorizontalRail's yield, as everywhere).

The chips themselves are unchanged: each page keeps its own labels, active rule and tap action. Menu
chips open C-036 FilterMenuOverlay; Search's category chips are `type: .button` and select.

## Proposed shape (d2m decides)

A component that holds the row and the scrolling, with the chips as its content: a `@ViewBuilder`
slot of C-035 FilterChips (R-08: §2 names the chip row as the slot). This lets the menu chips (most
pages) and the button chips (Search) both use it unchanged. If an items-array API reads better under
the rulebook, that is fine, as long as both chip types fit.

## Consumers to repoint (all nine)

| Screen | File | Today |
|---|---|---|
| enrollments-home | Screens/Enrollments/EnrollmentsHomeScreen.swift | the standard, inline |
| invites-home | Screens/Enrollments/InvitesHomeScreen.swift | the standard, inline |
| groups-home | Screens/Home/GroupsHomeScreen.swift | plain HStack inside the 16 side padding: no swipe |
| members-home | Screens/Members/MembersHomeScreen.swift | plain HStack inside the 16 side padding: no swipe |
| study-programs | Screens/Programs/StudyProgramsScreen.swift | plain HStack inside the 16 side padding: no swipe |
| media-home | Screens/Media/MediaHomeScreen.swift | plain HStack: no swipe. Its §2.1 "It does not scroll horizontally" is superseded by this ruling |
| enrollment-select-group | Screens/Groups/EnrollmentSelectGroupScreen.swift | plain HStack inside `.padding(pageMargin)`: no swipe |
| enrollment-select-program | Screens/Groups/EnrollmentSelectProgramScreen.swift | plain HStack inside `.padding(pageMargin)`: no swipe |
| search-home | Screens/Search/SearchHomeScreen.swift | HorizontalRail, but inside the header's 16 padding, so it clips at the margins instead of running full bleed |

Each consumer lifts the rail out of its side padding (the search field keeps its own 16 inset), and
keeps everything else as it is.

⚠️ `EnrollmentSelectProgramScreen.swift` carries the owner's own uncommitted edits in the working
tree. Edit on top of them and keep them; don't revert that file.

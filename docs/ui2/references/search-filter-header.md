# SearchFilterHeader — the one search + filter header

Owner 2026-11-02, walking invites on device: "there are consistency issues with the search + filter
bar again, huge gap between search and topnav, we've solved this before, I thought we built a
generalized solution for search and filters." Then: "make a shared component".

Only the chip row is shared today (C-130 FilterRail, `filter-rail.md`). Every Home-section nav root
hand-writes the header around it, so each new screen re-breaks the rules below. invites-home shipped
with 32pt under the TopNav and "All …" chips (fixed in `4eab2c3c`).

## What it is

One header, top to bottom:

1. **C-034 SearchField**: the editable form members-home uses. Focus is the field's own; while search
   is active the clear x always shows and ends the search (`clearDismisses`). The placeholder is a prop
   ("Search members", "Search invites", …).
2. **C-130 FilterRail**: full bleed. Its chips are a `@ViewBuilder` slot of C-035 FilterChips: menu
   chips on most screens, button chips where a screen needs them.

## The rules it owns (normative; all already ruled)

1. **No top inset under the shell TopNav.** In the app the shell's nav gap (`HomeSectionLayout.navGap`,
   16) is the space between the TopNav and the field, so the header adds none. A screen that draws its
   own C-019 row (the d2m previews, `showsNav`) gets a 16 top inset instead, so the frozen frames still
   measure field top = nav bottom + 16. (Owner 2026-11-01, enrollments-home.)
2. **Measured spacing:**
   - the field keeps the `space-page-margin` 16 side inset;
   - the gap from field to rail is 16;
   - the bottom inset is 16;
   - the rail is full bleed with its 16 inset inside the scroll content (`filter-rail.md` 1–6).
3. **Chip labels.** These are rules for the callers' labels. The header documents them, and its preview
   shows them.
   - A chip at rest names its dimension: "Orgs", "Groups", "Leaders", "Status", never "All …".
   - One pick shows that value.
   - Several picks show "n <noun>" (`FilterMenuOverlay.chipLabel`).
   - The C-036 menus have no "All …" row; Clear resets a filter.
   - A chip is active when its filter is not at rest.

   (Owner 2026-10-30, filter-multiselect; enrollments-home `EnrollmentsHomeMapper.swift:6`.)
4. **Search-active reporting.** Search is active while the field is focused or the query is non-empty.
   The header reports it, and the container hides the shell TopNav (`UI2HidesTopNavKey`), as
   members-home does.
5. **Pinned below the TopNav.** The header is the pinned section header of the screen's list, with
   `pinnedBelowTopNav()` and members-home's header material: an ultra-thin material under
   `color-layout-background` at 0.8.

## Consumers to repoint (six)

| Screen | File | Today |
|---|---|---|
| members-home | Screens/Members/MembersHomeScreen.swift | the pattern; spacers, no top inset |
| groups-home | Screens/Home/GroupsHomeScreen.swift | same as members-home |
| enrollments-home | Screens/Enrollments/EnrollmentsHomeScreen.swift | VStack, bottom-only inset |
| invites-home | Screens/Enrollments/InvitesHomeScreen.swift | VStack, top inset only with `showsNav` (4eab2c3c) |
| study-programs | Screens/Programs/StudyProgramsScreen.swift | check against the rules |
| media-home | Screens/Media/MediaHomeScreen.swift | check against the rules |

enrollment-select-group and enrollment-select-program have a search field over a rail too, but they
sit under a C-040 PageHeader, not the shell TopNav. Say whether they fit, and whether rule 1 holds
there or needs its own value.

Each consumer keeps its own chips, labels, actions and placeholder. Only the header around them
becomes the shared component.

**Visual reference:** Figma `3830:6932` ("Header" frame in Invites `3830:6919`, Figma section
`4773:11377`). It shows the field at (16,16) and the chips at y76 inside a 116-tall header, under the
frame's own nav row.

# Tag filter overlay — the sectioned chip flow

Owner ruling 2026-11-01 (feature `docs/features/tag-categories`, SPEC D6–D8, D12, D13). The normative
picture is **Figma `nVva9a2WvYmcWQo6zlHupO` node `4770:11375`**: the frame, plus the small two-state tag
chip component beside it.

## What it is

The overlay Media's **Tags** chip opens. It replaces only that one menu. Every other C-036 FilterMenuOverlay
use (Source, Leaders, Time, Upload-to on Media; every chip on members-home, groups-home,
enrollments-home, study-programs, the enrollment pickers; C-028) keeps today's list form, unchanged.

## Anatomy (from the frame, top → bottom)

1. **Header row**, as C-036's draft mode already draws it: **Clear** (C-049 link, top left) and **Save**
   (accent, top right).
2. **Sections**, stacked. Each section is:
   - an optional **header**: small uppercase caption in secondary text ("BOOKS OF THE BIBLE", "CONTENT");
   - its **options as a wrapping flow** of tag chips, left-aligned, wrapping to the next line at the
     right inset.
3. **The C-082 close disc**, bottom centre, as C-036 places it today.

**Tag chip** (the frame's two-state component): **unselected** = the label as plain text, no fill;
**selected** = the label on a white pill (dark text). Tapping toggles it in the draft.

## Inputs (the container already builds these)

`sections: [(title: String?, options: [(id: String, label: String)])]` in display order, plus the draft's
seed `selectedIDs: Set<String>`. A section whose `title` is nil draws no header. The container sends
**either one untitled section** (no categorized tags, so there are no headers at all) **or one or more
titled sections**, the last of which may be "CONTENT". Labels arrive display-ready ("1 Samuel", "Dogs").

## Behaviour (unchanged from C-036 draft mode)

- A chip tap toggles its id in the draft.
- **Save** hands the draft back (`onSave(Set<String>)`).
- **Clear** applies the empty selection and closes, as today.
- **✕** discards the draft (`onClose`).
- The list scrolls when the flow is taller than the screen, with C-036's bottom fade under the disc.

## Needs

- A wrapping (flow) layout inside `MakeReadyUI`. The app target's `FlowLayout` isn't reachable from the module.
- States to capture:
  - two sections, with a few selected;
  - one untitled section;
  - a long flow that scrolls under the fade.

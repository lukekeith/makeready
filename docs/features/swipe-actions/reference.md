# Swipe actions — how they work (reference for d2m)

**Source.** The owner's screen recording of the iOS 26 Phone app's Voicemail list,
`/Users/lukekeith/MakeReady/swipe action delete.MP4`: 13.3 s, 1320×2868 @ 60 fps, which is 440 pt
wide at 3×. The owner asked for exactly this behaviour as one **global** swipe-action solution that
any list row can use, with actions on the trailing side, the leading side, or both. They also ruled
that **delete always lives on the trailing side** (you swipe right to left to reach it). The first
consumer is library-home's note and memo rows, with Delete as its only action. Measurements below
are approximate (taken from the video at 3×); map them to the nearest tokens.

> "I like how the delete button pulls and expands, and has haptic feedback once it's ready to delete
> by just releasing. If I pull halfway before the haptic feedback it's just a circle button that
> doesn't expand and must be tapped." (owner 2026-11-21)

## 1. Anatomy

- **The row.** Its content is whatever the list already draws. At rest it is unchanged: same
  background, separators and insets. Once it is pulled even 1 pt off centre, the content sits on a
  **rounded card** (a raised surface fill with continuous corners of about 20 pt) that moves with it,
  so the moving row reads as a separate object. The card goes away again when the row settles back
  at rest.
- **The actions.** Each action is a separate **circle**, about 48 pt across, with a white glyph on a
  solid tint. The circles sit in a row in the space the content reveals, vertically centred on the
  row, about 8 pt from the screen edge, with about 8 pt between circles. They are not one strip under
  the row: each is its own shape. The video's tints are red (delete), orange and blue.
- **The order.** The action nearest the screen edge is the **edge action**. On the trailing side it
  is the destructive one (delete) whenever the row has one. It is the only action that can be
  **full-swiped**.

## 2. Reveal: following the finger

1. A horizontal drag on the row moves the content 1:1 with the finger. A vertical drag scrolls the
   list and never moves the row; use the house `.horizontalPan`, never a `DragGesture`.
2. As the gap opens, the circles **grow in, one at a time, starting from the edge**. The edge action
   appears first as a dot (about 6 pt) that scales up to its full size as the gap reaches its slot.
   Then the next action does the same, and so on. A circle's scale is set by how far the gap has
   uncovered its slot (0 to 1), so a slow drag shows a dot growing and a fast one shows the circles
   popping in in sequence. Opacity rises with the scale.
3. **Full reveal** means every circle is at full size: offset = (circles × 48) + (gaps × 8) + edge
   inset. That is about 64 pt for one action and about 176 pt for the video's three.
4. If a side has no actions, a drag toward it rubber-bands: it moves about a quarter of the distance
   and springs back.

## 3. The full swipe: arm, haptic, release

5. **Stretch.** Dragging past full reveal stretches the **edge action** from a circle into a
   **capsule** of the same height. Its leading end follows the finger and its trailing end stays at
   the edge inset. **The glyph stays centred in the capsule** while it stretches. The other circles
   stay where they are, at full strength.
6. **Arm.** When the offset passes the **arm threshold** (about 55 % of the row width), one spring
   (about 0.3 s) does three things together:
   - the capsule's leading edge **snaps** left to cover almost the whole row, leaving a sliver of the
     row card (about one circle wide) at the leading edge;
   - the **glyph slides from the capsule's centre to its leading edge** (about 16 pt in) and stays
     pinned there while armed;
   - the other circles **dim** to about 40 %.

   A **haptic** fires (medium impact). This is the "ready to delete" moment.
7. **Disarm.** Dragging back below the threshold minus about 5 % (hysteresis) reverses all three on
   the same spring:
   - the capsule shrinks back to following the finger;
   - the glyph slides back to the centre;
   - the circles return to full strength.

   A lighter haptic fires.
8. **Release while armed** runs the edge action. **Nothing moves sideways.** The capsule (glyph still
   at its leading edge), the dimmed circles and the sliver stay exactly where they are.
   - **For a removing action (delete):** the whole row's **height collapses to 0** in about 0.25 s
     (ease-in-out). It is clipped and top-anchored, so the content is cut off from the bottom, not
     scaled. The rows below slide up into the gap on the same timing, and the action fires.
   - **Order:** the collapse starts at release. The caller then removes the row from its data, and
     the collapsed row must not come back.

   Only an **armed** release does this. A fast flick that never armed does **not** full-swipe, so a
   delete always has its haptic warning first.

   (Corrected 2026-11-22 from the owner's second recording, `delete voicemail.MP4`. The first version
   had the glyph at the leading end while stretching, and the row sliding fully off screen on release.)

## 4. The half swipe: rest open, tap to act

9. **Release before arming**:
   - past about half of full reveal, the row springs to **rest open** at full reveal, with every
     circle full-size, the content card displaced and the capsule back to a circle;
   - below that, it springs closed.
10. **While a row is open:**
    - tapping a circle runs that action. For delete, the row then collapses as in step 8. The edge
      action does **not** expand on a tap: it is just a circle button.
    - tapping the row's content, starting to scroll the list, or swiping any other row closes the
      open row. That first tap is consumed: it does not open the item.
    - dragging the open row continues from its open offset, so it can be closed, or pulled on into a
      full swipe.
11. **One open row per list.** Opening a row closes any other.

## 5. Leading side

12. The leading side works the same way, mirrored. Its edge action is at the screen's leading edge
    and can be full-swiped if the caller allows it. **Delete is never put on the leading side.**

## 6. Motion and feedback

- **Following the finger:** no animation, 1:1. **Settling, rest-open, closing and the arm snap:** one
  critically damped spring, about 0.35 s (the house `ActionMenuMotion.slide` family).
- **Collapsing a deleted row:** height to 0 on the same spring, and the list's rows below follow.
- **Haptics:** a medium impact on arm and a light impact on disarm. Nothing on reveal, rest-open or
  tap.

## 7. Accessibility

- Each action is also a named accessibility action on the row ("Delete"), so VoiceOver and Switch
  Control can reach it without swiping. The circles carry their labels when visible.
- With Reduce Motion on, the circles fade instead of scaling, and the arm snap is instant; the
  haptics stay.

## 8. The library-home use (first consumer)

- **Trailing:** one action, **Delete**: the trash glyph on `color-error`, with full-swipe on. No
  leading actions.
- **What delete does:**
  - Delete runs at once, with no confirmation dialog: the haptic on arm is the warning.
  - Notes call `NoteActions.softDelete(id:)`, server memos call `MemoActions.softDelete(id:)`, and a
    memo still in the upload queue is removed from the queue.
- **If the delete fails:** the error goes to the banner with Retry (`/ios-error-surface`), and the row
  is back, because the list is drawn from AppState.

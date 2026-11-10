# C-019 TopNav — x-lock during the morph (device-proven prototype, 2026-11-09)

Owner rule (2026-11-09): **while the nav morphs (drag on the row, the page's pull-to-expand, or
scroll-to-collapse), the row's x axis is locked — the selected tab sits at the leading inset for
the whole morph, both directions, with no frame out of place.** Owner verified this exact diff on
device ("much much better") after four failed approaches.

## Why every scrollTo-based pin failed (device logs, `TNDBG` instrumentation)

1. **scrollTo lands a frame late.** `onChange(of: expansion)` → `proxy.scrollTo` is applied on the
   next update, so each frame renders the tabs at the new widths with the old offset — the held
   tab drifts by that frame's growth of every tab before it (10–50pt, speed-dependent) = jitter.
2. **A UIKit `contentOffset` write is clamped to the OLD contentSize** (written before layout), so
   on expand the target was capped short — still jitter.
3. **A frozen offset is clamped as the row shrinks** on collapse — the tab jumped right (~240pt).
4. (shell, fixed in 32bec01c) the row's own pan tracked the drag's finger and overwrote the offset;
   the shell now sets `.scrollDisabled` while a pin holds and pins the selected tab, not the finger.

## The design that works

- On a **named-tab hold** (the only pin the shell sends now), record `lock = (index, minX0, pos0)`:
  the tab's measured `minX` and its analytic content position at hold time.
- `contentPosition(index, at:)` = row inset at that growth + Σ preceding tabs `(hug + (124 − hug)·g)
  + gap`. Hugs are read back from frames **only while growth < 0.5** (1/(1−g) amplifies sub-point
  rounding as g → 1).
- `lockShift` = `pos(now) − pos0 + minX0 − inset(now)`; `lockShiftCollapsed` = the same at g = 0.
  Both are nil unless `pin != nil` (pin is a prop, so release re-renders).
- **At the hold** the real scroll offset moves by `lockShiftCollapsed` (the collapsed position is
  inside the scroll range at every expansion, so nothing clamps); **while held** no `scrollTo` runs
  and the content HStack takes `.offset(x: −(lockShift − lockShiftCollapsed))` — same layout pass,
  zero lag; **at release** the offset moves by the last `(lockShift − lockShiftCollapsed)` while
  `.offset` returns to 0 in the same update. Both writes are `UIScrollView.contentOffset` from a
  `UIViewRepresentable` in the content's background (`ScrollXLockRelease`).
- Unlocked holds (no hugs yet / finger pin) keep the old `scrollToPin` / `reanchorOnSelection`.

## The diff (against 32bec01c)

```diff
diff --git a/iphone/MakeReadyUI/TopNav.swift b/iphone/MakeReadyUI/TopNav.swift
index c4db16f2..7ca44768 100644
--- a/iphone/MakeReadyUI/TopNav.swift
+++ b/iphone/MakeReadyUI/TopNav.swift
@@ -77,6 +77,9 @@ struct TopNav: View {
         var viewport: CGFloat = 0
         /// §4 `pin` 1: the held (tab, f) and held x while pinned.
         var held: (tab: String, f: CGFloat, x: CGFloat)?
+        /// PROTOTYPE x-lock: the locked tab's index, its measured minX and content position at
+        /// hold time.
+        var lock: (index: Int, minX0: CGFloat, pos0: CGFloat)?
     }
     @State private var box = PinBox()
     /// §2 "Scroll range": the two measured inputs the trailing room is solved from — observed
@@ -150,6 +153,10 @@ struct TopNav: View {
                 // `viewport − inset − last tab width` — recomputed as `expansion` moves that width.
                 Color.clear.frame(width: trailingRoom, height: 0)
                 }
+                // PROTOTYPE x-lock: while a pin holds, the scroll offset is frozen and the row is
+                // shifted in this same layout pass, so the held tab cannot drift by a frame's growth.
+                .offset(x: -((lockShift ?? 0) - (lockShiftCollapsed ?? 0)))
+                .background(ScrollXLockRelease(shift: lockShift, base: lockShiftCollapsed))
             }
             .scrollIndicators(.hidden)
             // §2 table: row leading/trailing inset — as content margins, not padding, so the
@@ -169,14 +176,20 @@ struct TopNav: View {
             .onChange(of: pin) { old, new in
                 guard let new else {
                     box.held = nil
-                    reanchorOnSelection(proxy)
+                    // PROTOTYPE x-lock: the release already moved the shift into the scroll
+                    // offset (ScrollXLockRelease); re-anchor only an unlocked hold.
+                    if box.lock == nil { reanchorOnSelection(proxy) }
+                    box.lock = nil
                     return
                 }
-                if old.map({ !$0.sameHold(as: new) }) ?? true { box.held = hold(new) }
-                scrollToPin(new, proxy)
+                if old.map({ !$0.sameHold(as: new) }) ?? true {
+                    box.held = hold(new)
+                    box.lock = makeLock(new)
+                }
+                if box.lock == nil { scrollToPin(new, proxy) }
             }
             .onChange(of: expansion) { _, _ in
-                if let pin { scrollToPin(pin, proxy) }
+                if let pin, box.lock == nil { scrollToPin(pin, proxy) }
             }
         }
         .coordinateSpace(.named(Self.space))
@@ -205,7 +218,9 @@ struct TopNav: View {
     private func record(_ tab: String, _ frame: CGRect) {
         box.frames[tab] = frame
         let growth = NavTabButton.growth(at: progress)
-        if growth < 0.999 {
+        // PROTOTYPE: only near collapsed, where the read-back is stable (1/(1−g) amplifies
+        // sub-point rounding as g → 1).
+        if growth < 0.5 {
             box.hugs[tab] = (frame.width - Self.expandedWidth * growth) / (1 - growth)
         }
     }
@@ -264,6 +279,40 @@ struct TopNav: View {
         withTransaction(transaction) { proxy.scrollTo(selectedTab, anchor: anchor) }
     }
 
+    /// PROTOTYPE x-lock: a named-tab hold locks the row's x so the tab sits at the leading
+    /// inset through the whole morph. Needs every preceding tab's hug.
+    private func makeLock(_ pin: Pin) -> (index: Int, minX0: CGFloat, pos0: CGFloat)? {
+        guard let tab = pin.tab, let index = tabs.firstIndex(of: tab),
+              let frame = box.frames[tab], let pos = contentPosition(index) else { return nil }
+        return (index, frame.minX, pos)
+    }
+
+    /// The tab's leading x in the row's content at the current `expansion`, margin included.
+    private func contentPosition(_ index: Int, at expansion: CGFloat? = nil) -> CGFloat? {
+        let growth = NavTabButton.growth(at: expansion ?? progress)
+        var x = Self.collapsedInset + (Self.expandedInset - Self.collapsedInset) * growth
+        for tab in tabs.prefix(index) {
+            guard let hug = box.hugs[tab] else { return nil }
+            x += hug + (Self.expandedWidth - hug) * growth + Token.Space.elementGap
+        }
+        return x
+    }
+
+    /// The leftward shift since the hold that keeps the locked tab at the leading inset; nil
+    /// when no pin holds (the pin is a prop, so its release re-renders the row).
+    private var lockShift: CGFloat? {
+        guard pin != nil, let lock = box.lock, let pos = contentPosition(lock.index) else { return nil }
+        return pos - lock.pos0 + lock.minX0 - inset
+    }
+
+    /// The shift the collapsed row needs — the real scroll offset is moved by this at the hold,
+    /// because the collapsed position is within the scroll range at every `expansion`
+    /// (a frozen expanded offset was clamped as the row shrank, and the row jumped).
+    private var lockShiftCollapsed: CGFloat? {
+        guard pin != nil, let lock = box.lock, let pos = contentPosition(lock.index, at: 0) else { return nil }
+        return pos - lock.pos0 + lock.minX0 - Self.collapsedInset
+    }
+
     // GAP — C-069 §2: "fixed 124×96" expanded card, the end of every tab's growth; C-019 §4
     // `pin` restates it (w = hug + (124 − hug)·growth). C-069 keeps its geometry private.
     private static let expandedWidth: CGFloat = 124
@@ -288,3 +337,40 @@ struct TopNav: View {
         return Self.collapsedInset + (Self.expandedInset - Self.collapsedInset) * growth
     }
 }
+
+
+/// PROTOTYPE x-lock: on the hold (base nil → value) moves the scroll offset by `base`, the
+/// collapsed row's shift; while held the row's `.offset` covers `shift − base`; on release
+/// (→ nil, `.offset` → 0 in the same update) moves the scroll by the last `shift − base`.
+private struct ScrollXLockRelease: UIViewRepresentable {
+    let shift: CGFloat?
+    let base: CGFloat?
+
+    final class Coordinator { var last: (shift: CGFloat, base: CGFloat)? }
+
+    func makeCoordinator() -> Coordinator { Coordinator() }
+    func makeUIView(context: Context) -> UIView {
+        let view = UIView()
+        view.isUserInteractionEnabled = false
+        return view
+    }
+
+    func updateUIView(_ view: UIView, context: Context) {
+        let coordinator = context.coordinator
+        if let shift, let base {
+            if coordinator.last == nil { move(view, by: base) }
+            coordinator.last = (shift, base)
+            return
+        }
+        guard let last = coordinator.last else { return }
+        coordinator.last = nil
+        move(view, by: last.shift - last.base)
+    }
+
+    private func move(_ view: UIView, by delta: CGFloat) {
+        var ancestor = view.superview
+        while let current = ancestor, !(current is UIScrollView) { ancestor = current.superview }
+        guard let scrollView = ancestor as? UIScrollView, delta != 0 else { return }
+        scrollView.contentOffset.x += delta
+    }
+}
```

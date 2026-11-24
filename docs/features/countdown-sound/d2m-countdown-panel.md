# Countdown panel — d2m requirements (countdown-sound, owner 2026-11-24)

Change to screen `video-recorder`. Today the rail's **Countdown** tool (C-147 RailTool) cycles
Off → 3 s → 10 s on each tap (`VideoRecorderModel.swift:362`). Replace the cycling with a small panel.

## Behaviour
- Tapping **Countdown** on the rail opens a small panel (the recorder's existing bottom-sheet look, like
  the Length sheet), over the camera preview. Tapping outside or the tool again closes it.
- The panel has two rows:
  1. **Countdown** — a segmented choice **Off · 3 s · 10 s** (one selected; default Off).
  2. **Sound** — an on/off switch. Label "Sound"; caption "Beeps each second. Silent when your phone is
     on silent." **Default Off.** The switch is disabled (dimmed) while Countdown is Off.
- The rail tool's label keeps showing the chosen countdown ("Off", "3s", "10s").
- Choices apply at once and persist per device.

## Inputs the screen needs (added with defaults)
- `countdownSound: Bool = false` in the screen state, and `onCountdownSoundChange: (Bool) -> Void = { _ in }`.
- A new sheet case for the countdown panel; `onPreRollChange(PreRoll)` (or the existing pre-roll callback)
  for the segmented choice.

## States to capture
- countdown-panel with Off selected (Sound disabled)
- countdown-panel with 3 s selected, Sound off
- countdown-panel with 10 s selected, Sound on

## Rules
- UI 2.0 tokens only. No sound plays in any preview or capture (Sound Off in every fixture).

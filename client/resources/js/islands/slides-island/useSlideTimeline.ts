/**
 * useSlideTimeline.ts
 *
 * Computes a full-sequence timeline from all slide blocks without needing
 * a live DOM. This enables the scrubber to seek anywhere across all blocks.
 *
 * Timeline model:
 *   Each Phase contributes a time slot: durationMs + (autoAdvanceMs ?? pauseFallback)
 *   For tap-to-advance phases (autoAdvanceMs: null), we use a fixed display time
 *   so the scrubber can still represent them proportionally.
 *
 * The scrubber position (0–1) maps to a specific block + phase + offset.
 */

import type { Phase } from '../themes/base/types'

/** Default display time for tap-to-advance phases in the timeline (ms) */
const TAP_PHASE_DISPLAY_MS = 1500

/** Fallback animation duration when durationMs is not declared on a Phase */
const ANIM_FALLBACK_MS = 600

/** Fallback inter-block gap in the timeline */
const BLOCK_GAP_MS = 300

export interface PhaseSlot {
  blockIndex: number
  phaseIndex: number
  startMs: number      // absolute start in the full timeline
  durationMs: number   // animation duration
  pauseMs: number      // post-animation pause (0 for tap-to-advance)
  slotMs: number       // durationMs + pauseMs
}

export interface BlockSlot {
  blockIndex: number
  startMs: number
  endMs: number
  phases: PhaseSlot[]
}

export interface SlideTimeline {
  totalMs: number
  blocks: BlockSlot[]
  phases: PhaseSlot[]   // flat list across all blocks

  /** Map absolute time (ms) → { blockIndex, phaseIndex, offsetMs } */
  seek(absoluteMs: number): { blockIndex: number; phaseIndex: number; offsetMs: number }

  /** Map position 0–1 → same result */
  seekFraction(position: number): { blockIndex: number; phaseIndex: number; offsetMs: number }
}

/**
 * Build a timeline from pre-built sequences.
 * `sequences[i]` is the phases array for blocks[i].
 * Pass an empty array [] for blocks that haven't loaded a sequence yet —
 * they'll contribute a single placeholder slot.
 */
export function buildTimeline(sequences: Array<Phase[] | null>): SlideTimeline {
  const allPhases: PhaseSlot[] = []
  const blockSlots: BlockSlot[] = []
  let cursor = 0

  for (let bi = 0; bi < sequences.length; bi++) {
    const phases = sequences[bi]
    const blockStart = cursor
    const blockPhases: PhaseSlot[] = []

    if (!phases || phases.length === 0) {
      // Placeholder for an unloaded block
      const slot: PhaseSlot = {
        blockIndex: bi,
        phaseIndex: 0,
        startMs: cursor,
        durationMs: ANIM_FALLBACK_MS,
        pauseMs: TAP_PHASE_DISPLAY_MS,
        slotMs: ANIM_FALLBACK_MS + TAP_PHASE_DISPLAY_MS,
      }
      blockPhases.push(slot)
      allPhases.push(slot)
      cursor += slot.slotMs
    } else {
      for (let pi = 0; pi < phases.length; pi++) {
        const phase = phases[pi]
        const animMs = phase.durationMs ?? ANIM_FALLBACK_MS
        const pauseMs = phase.autoAdvanceMs ?? TAP_PHASE_DISPLAY_MS
        const slot: PhaseSlot = {
          blockIndex: bi,
          phaseIndex: pi,
          startMs: cursor,
          durationMs: animMs,
          pauseMs,
          slotMs: animMs + pauseMs,
        }
        blockPhases.push(slot)
        allPhases.push(slot)
        cursor += slot.slotMs
      }
    }

    blockSlots.push({
      blockIndex: bi,
      startMs: blockStart,
      endMs: cursor,
      phases: blockPhases,
    })

    // Gap between blocks
    if (bi < sequences.length - 1) cursor += BLOCK_GAP_MS
  }

  const totalMs = cursor

  function seek(absoluteMs: number) {
    const clamped = Math.max(0, Math.min(absoluteMs, totalMs - 1))
    // Find the phase slot containing this time
    for (let i = allPhases.length - 1; i >= 0; i--) {
      if (allPhases[i].startMs <= clamped) {
        const slot = allPhases[i]
        return {
          blockIndex: slot.blockIndex,
          phaseIndex: slot.phaseIndex,
          offsetMs: Math.min(clamped - slot.startMs, slot.durationMs),
        }
      }
    }
    return { blockIndex: 0, phaseIndex: 0, offsetMs: 0 }
  }

  function seekFraction(position: number) {
    return seek(position * totalMs)
  }

  return { totalMs, blocks: blockSlots, phases: allPhases, seek, seekFraction }
}

/**
 * Compute the absolute position (0–1) for a given block + phase.
 * Used to update the scrubber head when the player advances naturally.
 */
export function timelinePositionForPhase(
  timeline: SlideTimeline,
  blockIndex: number,
  phaseIndex: number,
): number {
  const slot = timeline.phases.find(
    p => p.blockIndex === blockIndex && p.phaseIndex === phaseIndex
  )
  if (!slot || timeline.totalMs === 0) return 0
  return slot.startMs / timeline.totalMs
}

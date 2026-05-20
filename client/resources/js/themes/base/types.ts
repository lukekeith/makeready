/**
 * themes/base/types.ts
 *
 * Shared types for the MakeReady theme system.
 * All themes and the player operate against these types exclusively.
 */

import type { AnimationPlaybackControls } from 'motion'

// ─── Tokens ───────────────────────────────────────────────────────────────────

/** All possible markdown token types the system recognises */
export type TokenType =
  | 'h1' | 'h2' | 'h3' | 'h4'
  | 'p'
  | 'li'
  | 'blockquote'
  | 'verse'
  | 'verse-reference'

export interface Token {
  /** Semantic type derived from markdown */
  type: TokenType
  /** Raw plain text (no HTML) */
  text: string
  /** Inline-parsed HTML — safe for v-html */
  html: string
  /** Position in the full flat token list for this read block (0-based) */
  index: number
  /** For 'li' tokens: the display number (e.g. 5 for "5. text"). undefined = unordered list. */
  listNumber?: number
}

// ─── Selections ───────────────────────────────────────────────────────────────

/**
 * A styled span over a read block's stored content. Mirrors the server
 * `activity_read_blocks.selections` JSONB shape and the iPhone
 * `ReadBlockSelectionStyle` enum (bold, highlight).
 *
 * Offsets are character positions into the raw stored content string
 * (markdown source). Style names beyond the known set are tolerated —
 * they're applied as `ThemePlayer__selection--{style}` and may be styled
 * by adding a matching SCSS rule, with no rendering-pipeline change.
 */
export interface ReadBlockSelection {
  start: number
  end: number
  style: string
}

// ─── Phase ────────────────────────────────────────────────────────────────────

/**
 * A Phase is the atomic unit of user-controlled progression.
 *
 * The player shows one phase at a time. The user taps / swipes / clicks
 * to move from one phase to the next.
 *
 * Rules enforced by the player:
 *   - If animation is playing when the user advances, the player snaps it
 *     to its final state (via .stop() + instant-appear), then waits for
 *     the next tap before advancing.
 *   - autoAdvanceMs is only honoured after the animation finishes naturally.
 *   - persist:true phases remain visible when later phases enter.
 */
export interface Phase {
  /** The tokens displayed in this phase */
  tokens: Token[]

  /**
   * The Motion animation that plays when this phase becomes active.
   *
   * Option A: provide a pre-built AnimationPlaybackControls.
   * Option B: provide a factory function () => AnimationPlaybackControls.
   *   Called at play-time so element references are always live DOM nodes.
   *
   * null = instant appear (no animation).
   */
  animation: AnimationPlaybackControls | (() => AnimationPlaybackControls) | null

  /**
   * The duration of the animation in milliseconds.
   * Must be provided so the scrubber can compute the total timeline length
   * without running the animation. If omitted, defaults to 0.
   */
  durationMs?: number

  /**
   * Milliseconds to wait after animation.finished before auto-advancing.
   * null = never auto-advance; user must tap/swipe to proceed.
   */
  autoAdvanceMs: number | null

  /**
   * When true, this phase's tokens stay rendered when later phases appear.
   * When false, this phase's tokens are hidden when the next phase starts.
   * Default: true (most themes accumulate visible content).
   */
  persist: boolean
}

// ─── Sequence ─────────────────────────────────────────────────────────────────

/**
 * The complete output of a theme for one read block.
 * The player receives this from theme.buildSequence() and iterates through it.
 */
export interface Sequence {
  phases: Phase[]
}

// ─── Theme context ────────────────────────────────────────────────────────────

/**
 * Passed to the theme by the player at mount time.
 * Everything the theme needs to build its sequence.
 */
export interface ThemeContext {
  /**
   * The player's root container element.
   * Theme DOM queries should be scoped to this element.
   * Tokens are rendered as: container.querySelector('[data-token-index="N"]')
   */
  container: HTMLElement

  /** Full flat list of parsed tokens for this read block */
  tokens: Token[]

  /** True if the OS prefers reduced motion — themes should skip animations */
  prefersReducedMotion: boolean
}

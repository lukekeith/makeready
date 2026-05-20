/**
 * themes/base/ThemeBase.ts
 *
 * Abstract base class all themes must extend.
 *
 * Lifecycle (managed by ThemePlayer.vue):
 *   1. theme.mount(context)    — set up backgrounds, load assets, store context
 *   2. theme.buildSequence()   — return a Sequence; MUST NOT start any animation
 *   3. player iterates phases, calling phase.animation.play() for each
 *   4. theme.unmount()         — clean up backgrounds, timers, event listeners
 *
 * Contract:
 *   - Themes MUST NOT call animation.play() themselves.
 *   - Themes MUST NOT auto-play anything in mount() or buildSequence().
 *   - buildSequence() should be idempotent — calling it twice returns
 *     equivalent sequences.
 *   - If prefersReducedMotion is true, return null for all animations
 *     and set autoAdvanceMs: 0 so content is immediately visible.
 *
 * Theme authors can do anything else they want:
 *   - Add background elements to context.container (absolutely positioned)
 *   - Load images, fonts, or other assets
 *   - Run imperative canvas / WebGL animations in mount() as long as
 *     they don't interfere with the token phases
 *   - Import a per-theme .scss file for custom styles
 */

import type { ThemeContext, Sequence } from './types'

export abstract class ThemeBase {
  /** Human-readable display name */
  abstract readonly name: string

  /** URL-safe identifier matching the database slug */
  abstract readonly slug: string

  /** Short description shown in theme pickers */
  abstract readonly description: string

  /**
   * When true the player suppresses its default token rendering entirely.
   * Use this when the theme mounts its own DOM in mount() (e.g. Star Wars crawl).
   * Default: false — player renders [data-token-index] elements as usual.
   */
  readonly ownsRendering: boolean = false

  /** Set by mount(), available to buildSequence() and unmount() */
  protected context!: ThemeContext

  /**
   * Called once by the player before buildSequence().
   * Override to set up backgrounds, import styles, etc.
   * Always call super.mount(context) first.
   */
  mount(context: ThemeContext): void {
    this.context = context
  }

  /**
   * Build and return the complete Sequence for the current read block.
   * The player calls this once after mount() to get all phases upfront.
   *
   * The returned animation objects are built but NOT played.
   * The player calls phase.animation.play() at the right moment.
   */
  abstract buildSequence(): Sequence

  /**
   * Called when the player unmounts this theme.
   * Clean up any DOM added in mount(), cancel timers, etc.
   */
  unmount(): void {}

  /**
   * Render the visual state at a given progress (0–1) within a single phase.
   *
   * Called by the scrubber / external clock to render the exact "frame"
   * at any point in the sequence. The player handles snapping completed
   * phases and hiding future phases — this method only needs to render
   * the *current* phase at the given progress.
   *
   * Default implementation: linear opacity fade (0 → 1).
   * Themes that animate other properties (transform, filter, textContent)
   * MUST override this to produce correct scrubber frames.
   *
   * @param phaseIndex - which phase to render
   * @param progress   - 0 = animation start, 1 = animation end
   */
  seekTo(phaseIndex: number, progress: number): void {
    const seq = this.lastSequence
    if (!seq) return
    const phase = seq.phases[phaseIndex]
    if (!phase) return

    // Default: interpolate opacity on each token element
    for (const token of phase.tokens) {
      const el = this.el(token.index)
      if (el) {
        el.style.opacity = String(progress)
        el.style.transform = 'none'
        el.style.filter = 'none'
      }
    }
  }

  /**
   * Stored by the player after buildSequence() so seekTo() can
   * reference phase data without the player passing it every call.
   */
  lastSequence: import('./types').Sequence | null = null

  // ─── Protected helpers ────────────────────────────────────────────────────

  /**
   * Get the rendered DOM element for a token by its index.
   * Returns null if the element isn't in the DOM yet.
   */
  protected el(tokenIndex: number): HTMLElement | null {
    return this.context.container.querySelector(
      `[data-token-index="${tokenIndex}"]`
    ) as HTMLElement | null
  }

  /**
   * Get DOM elements for an array of tokens.
   * Filters out any null results (unmounted tokens).
   */
  protected els(tokens: import('./types').Token[]): HTMLElement[] {
    return tokens
      .map(t => this.el(t.index))
      .filter((el): el is HTMLElement => el !== null)
  }

  /**
   * Move [data-token-index] elements from the container into a new wrapper,
   * resetting each element's opacity to 0 after re-parenting.
   *
   * Re-parenting can invalidate CSS rules that kept the element at opacity:0,
   * so we always force it inline to guarantee Motion animates from invisible.
   */
  protected wrapTokens(wrapper: HTMLElement): void {
    const tokenEls = Array.from(
      this.context.container.querySelectorAll('[data-token-index]')
    )
    for (const el of tokenEls) {
      wrapper.appendChild(el);
      (el as HTMLElement).style.opacity = '0'
    }
  }

  /**
   * Called by the player after sequence.value is set and Vue has rendered
   * the phase/token elements into the DOM (after nextTick).
   *
   * Use this instead of buildSequence() for any setup that requires the
   * token elements to actually exist in the DOM — e.g. setting opacity:0
   * inline, moving elements, measuring heights, etc.
   *
   * Default: no-op. Override in themes that need post-render DOM setup.
   */
  afterRender?(): void

  /**
   * Reset all token elements to opacity:0 before building animations.
   * Call at the start of buildSequence() in any theme that fades elements in,
   * to guard against DOM reuse across play cycles.
   */
  protected hideAllTokens(): void {
    for (const token of this.context.tokens) {
      const el = this.el(token.index)
      if (el) el.style.opacity = '0'
    }
  }

  protected instantPhase(
    tokens: import('./types').Token[],
    autoAdvanceMs: number | null = null,
    persist = true
  ): import('./types').Phase {
    return { tokens, animation: null, autoAdvanceMs, persist }
  }
}

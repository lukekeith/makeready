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

  /**
   * When true the theme drives its container's native scrollTop (see the
   * native-scroll helpers below) instead of letting the player snap a static
   * final frame. The player keeps calling seekTo() on the final frame instead
   * of short-circuiting, so the theme stays in programmatic-follow mode until
   * playback actually stops — only then does it release the surface for
   * read-back. Default: false.
   */
  readonly usesNativeScroll: boolean = false

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
   * Usable content height of the theme container — the border-box height
   * minus the actual top and bottom padding.
   *
   * Themes reserve chrome space (the lesson header up top, the scrubber /
   * progress / "continue" controls at the bottom) via container padding that
   * is driven by the --member-lesson-header and --member-lesson-footer CSS
   * variables (see ThemePlayer's topInset / bottomInset). Reading the real
   * resolved padding here — instead of a per-theme hardcoded constant — keeps
   * every theme's teleprompter parking consistent with that reservation, so
   * the last line always parks above the bottom controls and they all respond
   * to safe-area changes the same way.
   */
  protected contentHeight(container: HTMLElement | undefined = this.context?.container): number {
    if (!container) return 0
    const cs = getComputedStyle(container)
    return container.clientHeight - parseFloat(cs.paddingTop || '0') - parseFloat(cs.paddingBottom || '0')
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

  // ─── Native scroll (teleprompter follow + idle read-back) ──────────────────
  //
  // Shared replacement for per-theme `scrollTrack()` transform math. Instead of
  // translating a track with a flex-center correction, we make the container a
  // native scroll surface and drive `scrollTop` directly:
  //
  //   • While the clock drives the sequence, seekTo() fires every frame and we
  //     keep the container in programmatic-follow mode (overflow hidden, we own
  //     scrollTop) so the latest revealed line parks above the footer band.
  //   • When the clock stops (paused / parked) seekTo() stops firing; after
  //     IDLE_MS of silence we flip the container to `overflow-y: auto` so the
  //     reader can scroll back through content that auto-advanced off-screen.
  //   • Any new seekTo() reclaims control instantly.
  //
  // A theme opts in by: adding the `theme-native-scroll` class to its container
  // in mount(), calling driveNativeScroll(lastRevealedEl) at the end of seekTo(),
  // and calling teardownNativeScroll() in unmount(). The container's overflow,
  // touch-action and scrollbar styling live in ThemePlayer.scss; the theme only
  // needs `margin: auto 0` on its track so short content centers and long
  // content top-aligns and scrolls (never `justify-content: center`, which clips
  // the top of overflowing content out of reach).

  private _idleScrollTimer: ReturnType<typeof setTimeout> | null = null
  private static readonly NATIVE_SCROLL_IDLE_MS = 140

  /**
   * Park `lastEl`'s bottom at the container's padded bottom edge via scrollTop.
   * `offsetTop` is measured from the container's padding edge, so a line's
   * distance from the scroll origin is padTop + offsetTop; solving
   *   padTop + lineBottom - scrollTop = clientHeight - padBottom
   * gives the target below. Clamped to [0, maxScroll], so when content fits
   * (maxScroll ≤ 0) it pins at 0 and the track's `margin: auto` centers it.
   */
  protected followScroll(
    lastEl: HTMLElement | null,
    container: HTMLElement | undefined = this.context?.container,
  ): void {
    if (!lastEl || !container) return
    const cs = getComputedStyle(container)
    const padTop = parseFloat(cs.paddingTop || '0')
    const padBottom = parseFloat(cs.paddingBottom || '0')
    const lineBottom = lastEl.offsetTop + lastEl.offsetHeight
    const maxScroll = container.scrollHeight - container.clientHeight
    const target = padTop + lineBottom + padBottom - container.clientHeight
    container.scrollTop = Math.max(0, Math.min(target, Math.max(0, maxScroll)))
  }

  /** Reassert programmatic control: cancel any pending idle release and take
   *  the container out of user-scroll mode. */
  protected reclaimScroll(
    container: HTMLElement | undefined = this.context?.container,
  ): void {
    if (this._idleScrollTimer !== null) {
      clearTimeout(this._idleScrollTimer)
      this._idleScrollTimer = null
    }
    container?.classList.remove('theme-native-scrollable')
  }

  /** After IDLE_MS with no further seekTo(), release the container to the reader
   *  if (and only if) it actually overflows. */
  protected armIdleScroll(
    container: HTMLElement | undefined = this.context?.container,
  ): void {
    if (!container) return
    if (this._idleScrollTimer !== null) clearTimeout(this._idleScrollTimer)
    this._idleScrollTimer = setTimeout(() => {
      this._idleScrollTimer = null
      if (container.scrollHeight - container.clientHeight > 1) {
        container.classList.add('theme-native-scrollable')
      }
    }, ThemeBase.NATIVE_SCROLL_IDLE_MS)
  }

  /** Convenience for seekTo(): reclaim, follow the last revealed element, then
   *  arm the idle read-back release. */
  protected driveNativeScroll(lastEl: HTMLElement | null): void {
    const container = this.context?.container
    if (!container) return
    this.reclaimScroll(container)
    this.followScroll(lastEl, container)
    this.armIdleScroll(container)
  }

  /** Call from unmount(): cancel the idle timer and drop the scrollable class. */
  protected teardownNativeScroll(): void {
    if (this._idleScrollTimer !== null) {
      clearTimeout(this._idleScrollTimer)
      this._idleScrollTimer = null
    }
    this.context?.container?.classList.remove('theme-native-scrollable')
  }
}

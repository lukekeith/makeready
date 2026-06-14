import { animate } from 'motion'
import { ThemeBase } from '../base/ThemeBase'
import type { Sequence, ThemeContext } from '../base/types'
import './dramatic-reveal.scss'

/**
 * Dramatic Reveal
 *
 * Cinematic zoom-out reveal. All content appears at once — the camera
 * starts zoomed in (scale 2, invisible) and pulls back to reveal
 * the full text in place. One phase, one motion.
 *
 * Auto-scales typography based on content length.
 */
export class DramaticReveal extends ThemeBase {
  readonly name = 'Dramatic Reveal'
  readonly slug = 'dramatic-reveal'
  readonly description = 'Cinematic zoom-out — text revealed as the camera pulls back'
  override readonly usesNativeScroll = true

  private contentWrap: HTMLElement | null = null

  override mount(context: ThemeContext): void {
    super.mount(context)
    const container = context.container
    container.classList.add('theme-dramatic-reveal-container', 'theme-native-scroll')
    const totalChars = context.tokens.reduce((n, t) => n + t.text.length, 0)
    container.classList.add(this.scaleClass(totalChars))
  }

  override afterRender(): void {
    // Wrap all token elements in a single div so we can scale them together
    const container = this.context?.container
    if (!container) return

    const wrap = document.createElement('div')
    wrap.className = 'dr-content-wrap'
    // Start hidden + zoomed in
    wrap.style.opacity = '0'
    wrap.style.transform = 'scale(2)'

    const phases = container.querySelectorAll('.ThemePlayer__phase')
    phases.forEach(phase => wrap.appendChild(phase))
    container.appendChild(wrap)
    this.contentWrap = wrap

    // Set all tokens to visible — the wrapper controls visibility via its own opacity
    const tokenEls = container.querySelectorAll('[data-token-index]')
    tokenEls.forEach(el => { (el as HTMLElement).style.opacity = '1' })
  }

  override unmount(): void {
    this.teardownNativeScroll()
    const container = this.context?.container
    if (!container) return
    container.classList.remove('theme-dramatic-reveal-container', 'theme-native-scroll')
    container.className = container.className
      .replace(/\bscale-\S+/g, '')
      .trim()
    this.contentWrap = null
  }

  private scaleClass(charCount: number): string {
    if (charCount < 60)  return 'scale-xl'
    if (charCount < 160) return 'scale-lg'
    if (charCount < 320) return 'scale-md'
    if (charCount < 600) return 'scale-sm'
    return 'scale-xs'
  }

  /**
   * Native-scroll version. The zoom (phase 0) stays a transform on the content
   * wrap; overflow handling moves to the container's native scrollTop so it
   * shares the teleprompter-follow + idle read-back behaviour of the other
   * themes (no more flex-center translateY correction).
   *
   *   • Phase 0 (zoom): scale the wrap 2 → 1; keep the surface pinned to the
   *     top (scrollTop 0) while we own it.
   *   • Phase 1 (scroll, present only when content overflows): ease the native
   *     scrollTop from 0 → maxScroll. Because scrollHeight already includes the
   *     reserved footer padding, scrollTop === maxScroll parks the last line
   *     just above the footer band.
   *
   * Both phases arm the idle release, so once the clock stops the container
   * flips to `overflow-y: auto` and the reader can scroll freely.
   */
  override seekTo(phaseIndex: number, progress: number): void {
    if (!this.contentWrap || !this.context) return
    const container = this.context.container

    if (phaseIndex === 0) {
      const scale = 2 - progress          // 2 → 1
      this.contentWrap.style.opacity = String(progress)
      this.contentWrap.style.transform = `scale(${scale})`
      this.reclaimScroll(container)
      container.scrollTop = 0
      this.armIdleScroll(container)
    } else {
      this.contentWrap.style.opacity = '1'
      this.contentWrap.style.transform = 'scale(1)'
      const maxScroll = Math.max(0, container.scrollHeight - container.clientHeight)
      this.reclaimScroll(container)
      container.scrollTop = maxScroll * progress
      this.armIdleScroll(container)
    }
  }

  buildSequence(): Sequence {
    const { tokens, prefersReducedMotion } = this.context

    if (prefersReducedMotion) {
      if (this.contentWrap) {
        this.contentWrap.style.opacity = '1'
        this.contentWrap.style.transform = 'scale(1)'
      }
      return { phases: [this.instantPhase(tokens, null)] }
    }

    const phases = []

    // Phase 1: zoom-out reveal
    phases.push({
      tokens,
      durationMs: 1800,
      animation: () => {
        if (!this.contentWrap) {
          return animate(document.createElement('div'), { opacity: [0, 1] }, { duration: 0.001 })
        }
        return animate(
          this.contentWrap,
          { opacity: [0, 1], scale: [2, 1] },
          { duration: 1.8, easing: [0.16, 1, 0.3, 1] }
        )
      },
      autoAdvanceMs: 500,
      persist: true,
    })

    // Phase 2: scroll up if content overflows (measured after render)
    // We estimate overflow from token count — actual measurement happens in seekTo
    const estContentH = tokens.length * 40
    const estOverflow = Math.max(0, estContentH - 400)
    if (estOverflow > 0) {
      // Duration proportional to overflow distance at ~120px/s
      const scrollDurationMs = Math.max(1500, Math.round((estOverflow / 120) * 1000))
      phases.push({
        tokens,
        durationMs: scrollDurationMs,
        animation: null,  // driven by seekTo
        autoAdvanceMs: null,
        persist: true,
      })
    }

    return { phases }
  }
}

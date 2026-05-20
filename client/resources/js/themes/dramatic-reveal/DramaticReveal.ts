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

  private contentWrap: HTMLElement | null = null

  override mount(context: ThemeContext): void {
    super.mount(context)
    const container = context.container
    container.classList.add('theme-dramatic-reveal-container')
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
    const container = this.context?.container
    if (!container) return
    container.classList.remove('theme-dramatic-reveal-container')
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
   * Compute the total translateY needed to scroll from the flex-centered
   * position to where the last line is just visible above the bottom edge.
   *
   * When flex centers the content, the top of the content is at:
   *   (containerH - contentH) / 2   from the container's padding edge.
   * We need to shift up so the bottom of the content aligns with the
   * container bottom, i.e. translateY = -((containerH - contentH) / 2 + overflow)
   * which simplifies to -(contentH - containerH / 2 - containerH / 2) = -overflow
   * but from the centered start: shift = (contentH - containerH) / 2 + (contentH - containerH) / 2
   * = contentH - containerH = overflow.
   *
   * Actually simpler: the content is centered, so the bottom edge extends
   * overflow/2 past the container bottom. We need to shift up by that
   * PLUS the other overflow/2 that's above center = full overflow.
   */
  override seekTo(phaseIndex: number, progress: number): void {
    if (!this.contentWrap || !this.context) return

    const container = this.context.container
    const containerH = container.clientHeight - 96  // padding 48*2
    const contentH = this.contentWrap.scrollHeight
    const overflow = Math.max(0, contentH - containerH)

    // Flex centers the content. clampY undoes that centering so the top
    // sits at the container's top edge (only needed when content overflows).
    const clampY = overflow > 0 ? overflow / 2 : 0

    if (phaseIndex === 0) {
      // Phase 0: zoom-out reveal
      const scale = 2 - progress          // 2 → 1
      this.contentWrap.style.opacity = String(progress)
      this.contentWrap.style.transform = clampY > 0
        ? `translateY(${clampY}px) scale(${scale})`
        : `scale(${scale})`
    } else {
      // Phase 1: ease up until the last line is visible at the bottom.
      // Start: top at container top (clampY applied).
      // End: bottom of content at container bottom.
      // The top will scroll off by (overflow) — unavoidable for very long content.
      // Cap so we never scroll more than needed.
      this.contentWrap.style.opacity = '1'
      const y = clampY - overflow * progress
      this.contentWrap.style.transform = `translateY(${y}px)`
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

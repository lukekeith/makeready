import { ThemeBase } from '../base/ThemeBase'
import type { Sequence, Phase, ThemeContext, Token } from '../base/types'
import './bold-slide.scss'

/**
 * Bold Slide
 *
 * Each line slides in from the right with a horizontal blur, easing into
 * its final position. All lines are present in the DOM from the start
 * (positioned off-screen) so positions don't shift as new lines appear.
 *
 * When enough lines fill the viewport, the entire track scrolls up
 * to keep the latest line visible at the bottom.
 *
 * Auto-scales typography based on content length.
 */
export class BoldSlide extends ThemeBase {
  readonly name = 'Bold Slide'
  readonly slug = 'bold-slide'
  readonly description = 'Lines slide in from the right with blur — stacks and scrolls like a teleprompter'
  readonly ownsRendering = true

  private trackEl: HTMLElement | null = null
  private lineEls: HTMLElement[] = []

  override mount(context: ThemeContext): void {
    super.mount(context)
    const container = context.container
    container.classList.add('theme-bold-slide-container')
    const totalChars = context.tokens.reduce((n, t) => n + t.text.length, 0)
    container.classList.add(this.scaleClass(totalChars))

    // Build the track with all lines
    const track = document.createElement('div')
    track.className = 'bs-track'

    const lines: HTMLElement[] = []
    let liRunning = false

    for (const token of context.tokens) {
      const line = document.createElement('div')
      line.className = 'bs-line bs-line--pending'

      // Track list item runs for CSS counter reset
      if (token.type === 'li') {
        if (!liRunning) liRunning = true
        line.classList.add('bs-line--li')
      } else {
        liRunning = false
      }

      const tag = this.tagFor(token.type)
      const inner = document.createElement(tag)
      if (token.type === 'li' && token.listNumber != null) {
        inner.innerHTML = `<span class="bs-item-num">${token.listNumber}.</span> ${token.html}`
      } else if (token.type === 'li') {
        inner.innerHTML = `<span class="bs-item-bullet">&bull;</span> ${token.html}`
      } else {
        inner.innerHTML = token.html
      }
      line.appendChild(inner)

      track.appendChild(line)
      lines.push(line)
    }

    container.appendChild(track)
    this.trackEl = track
    this.lineEls = lines
  }

  override unmount(): void {
    const container = this.context?.container
    if (!container) return
    container.classList.remove('theme-bold-slide-container')
    container.className = container.className
      .replace(/\bscale-\S+/g, '')
      .trim()
    this.trackEl?.remove()
    this.trackEl = null
    this.lineEls = []
  }

  buildSequence(): Sequence {
    const { tokens, prefersReducedMotion } = this.context

    if (prefersReducedMotion) {
      this.lineEls.forEach(el => {
        el.classList.remove('bs-line--pending')
        el.classList.add('bs-line--revealed')
      })
      return { phases: [this.instantPhase(tokens, null)] }
    }

    // One phase per line — headings solo, each li solo, paragraphs solo
    const phases: Phase[] = []
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i]
      const durMs = this.durationFor(token)
      phases.push({
        tokens: [token],
        durationMs: durMs,
        animation: null,   // We drive animation via CSS classes in seekTo
        autoAdvanceMs: this.pauseAfter(token),
        persist: true,
      })
    }

    return { phases }
  }

  override seekTo(phaseIndex: number, progress: number): void {
    if (!this.trackEl || this.lineEls.length === 0) return

    const container = this.context?.container
    if (!container) return

    // Reveal all lines up to and including current phase
    for (let i = 0; i < this.lineEls.length; i++) {
      const line = this.lineEls[i]
      if (i < phaseIndex) {
        // Fully revealed
        line.classList.remove('bs-line--pending')
        line.classList.add('bs-line--revealed')
        line.style.transform = ''
        line.style.opacity = ''
        line.style.filter = ''
      } else if (i === phaseIndex) {
        // Current line — interpolate from pending to revealed
        line.classList.remove('bs-line--pending', 'bs-line--revealed')
        const x = 100 * (1 - progress)
        const blur = 8 * (1 - progress)
        line.style.transform = `translateX(${x}%)`
        line.style.opacity = String(progress)
        line.style.filter = `blur(${blur}px)`
      } else {
        // Still pending — off-screen right
        line.classList.remove('bs-line--revealed')
        line.classList.add('bs-line--pending')
        line.style.transform = ''
        line.style.opacity = ''
        line.style.filter = ''
      }
    }

    // Scroll the track up if revealed content exceeds the container
    this.scrollTrack(phaseIndex, container)
  }

  private scrollTrack(revealedUpTo: number, container: HTMLElement): void {
    if (!this.trackEl) return

    // Effective content area (container minus vertical padding).
    const containerH = container.clientHeight - 128

    // Full track height — all lines (revealed + pending) take up vertical
    // space even when pending (they're translated X-offscreen, not removed
    // from flow), so this is stable across the whole sequence.
    const trackH = this.trackEl.offsetHeight

    // When the full content fits, let CSS `justify-content: center` handle
    // vertical centering — no translate needed.
    if (trackH <= containerH) {
      this.trackEl.style.transform = ''
      return
    }

    // Content overflows: teleprompter-scroll so the most recently revealed
    // line parks at the bottom of the visible area.
    //
    // With `justify-content: center`, the track's natural top sits at
    //   (containerH - trackH) / 2
    // (negative, since trackH > containerH — i.e. the track already
    // overflows equally above and below). To put the bottom of the revealed
    // portion at y = containerH, we translate by:
    //   containerH - (naturalTop + revealedH)
    //   = (containerH + trackH) / 2 - revealedH
    let revealedH = 0
    for (let i = 0; i <= revealedUpTo && i < this.lineEls.length; i++) {
      revealedH += this.lineEls[i].offsetHeight
    }

    const ty = (containerH + trackH) / 2 - revealedH
    this.trackEl.style.transform = `translateY(${ty}px)`
  }

  private durationFor(token: Token): number {
    if (token.type === 'h1') return 800
    if (token.type === 'h2' || token.type === 'h3') return 700
    if (token.type === 'li') return 500
    if (token.type === 'blockquote') return 700
    return Math.min(900, Math.max(500, token.text.length * 4))
  }

  private pauseAfter(token: Token): number {
    if (token.type === 'h1') return 800
    if (token.type === 'h2' || token.type === 'h3') return 600
    if (token.type === 'li') return 400
    if (token.type === 'blockquote') return 800
    return Math.min(2000, Math.max(600, token.text.length * 18))
  }

  private scaleClass(charCount: number): string {
    if (charCount < 60)  return 'scale-xl'
    if (charCount < 160) return 'scale-lg'
    if (charCount < 320) return 'scale-md'
    if (charCount < 600) return 'scale-sm'
    return 'scale-xs'
  }

  private tagFor(type: string): string {
    if (type === 'h1') return 'h1'
    if (type === 'h2') return 'h2'
    if (type === 'h3') return 'h3'
    if (type === 'h4') return 'h4'
    if (type === 'blockquote') return 'blockquote'
    return 'p'
  }
}

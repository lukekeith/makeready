import { animate } from 'motion'
import { ThemeBase } from '../base/ThemeBase'
import type { ThemeContext, Sequence, Phase, Token } from '../base/types'
import './gentle-fade.scss'

/**
 * Gentle Fade
 *
 * Centered, auto-scaled presentation. All content fades in sequentially:
 *   1. All heading tokens (h1-h4) fade in together
 *   2. 500ms pause
 *   3. Each remaining element fades in individually, in markdown order
 *
 * Font size scales automatically based on total content length.
 * All phases auto-advance — no tapping required.
 */
export class GentleFade extends ThemeBase {
  readonly name = 'Gentle Fade'
  readonly slug = 'gentle-fade'
  readonly description = 'Centered auto-scaling fade — headings first, then content in sequence'

  private trackWrap: HTMLElement | null = null

  override mount(context: ThemeContext): void {
    super.mount(context)
    const container = context.container
    container.classList.add('theme-gentle-fade-container')
    const totalChars = context.tokens.reduce((n, t) => n + t.text.length, 0)
    container.classList.add(this.scaleClass(totalChars))
  }

  /** Hide all tokens, then wrap phases in a track div for scroll-up */
  override afterRender(): void {
    this.hideAllTokens()

    const container = this.context?.container
    if (!container) return

    // Wrap all phase elements in a track so we can translateY when content overflows
    const wrap = document.createElement('div')
    wrap.className = 'gf-track'
    const phases = Array.from(container.querySelectorAll('.ThemePlayer__phase'))
    phases.forEach(phase => wrap.appendChild(phase))
    container.appendChild(wrap)
    this.trackWrap = wrap
  }

  override unmount(): void {
    const container = this.context?.container
    if (!container) return
    container.classList.remove('theme-gentle-fade-container')
    container.className = container.className
      .replace(/\bscale-\S+/g, '')
      .trim()
    this.trackWrap = null
  }

  override seekTo(phaseIndex: number, progress: number): void {
    const seq = this.lastSequence
    if (!seq) return
    const phase = seq.phases[phaseIndex]
    if (!phase) return

    // Default opacity interpolation for the current phase
    for (const token of phase.tokens) {
      const el = this.el(token.index)
      if (el) {
        el.style.opacity = String(progress)
        el.style.transform = 'none'
        el.style.filter = 'none'
      }
    }

    // Scroll up if revealed content exceeds the container
    this.scrollTrack(phaseIndex)
  }

  /**
   * Position the track so the first revealed phase is always visible at the
   * top of the container, never clipped above it by `justify-content: center`.
   *
   * Under flex-center with overflow, the track's natural top sits at
   * `-(totalContentH - containerH) / 2` (above the container). We correct
   * for that with `overflow_total/2` so the top parks at the container's
   * padded top. As phases reveal and the revealed height exceeds the
   * container, we let it teleprompter-scroll up so the latest phase stays
   * at the bottom — `shiftY = min(0, containerH - revealedH)`.
   */
  private scrollTrack(revealedUpTo: number): void {
    if (!this.trackWrap || !this.context) return

    const container = this.context.container
    const containerH = container.clientHeight - 96  // subtract padding (48 * 2)
    const totalContentH = this.trackWrap.scrollHeight

    if (totalContentH <= containerH) {
      this.trackWrap.style.transform = ''
      return
    }

    const phases = this.trackWrap.querySelectorAll('.ThemePlayer__phase')
    let revealedH = 0
    for (let i = 0; i <= revealedUpTo && i < phases.length; i++) {
      revealedH += (phases[i] as HTMLElement).offsetHeight
    }

    const shiftY = Math.min(0, containerH - revealedH)
    const centerCorrection = (totalContentH - containerH) / 2
    this.trackWrap.style.transform = `translateY(${shiftY + centerCorrection}px)`
  }

  buildSequence(): Sequence {
    const { tokens, prefersReducedMotion } = this.context

    if (prefersReducedMotion) {
      tokens.forEach(t => {
        const el = this.el(t.index)
        if (el) el.style.opacity = '1'
      })
      return { phases: [this.instantPhase(tokens, null)] }
    }

    const headingTypes = new Set(['h1', 'h2', 'h3', 'h4'])
    const headings = tokens.filter(t => headingTypes.has(t.type))
    const body = tokens.filter(t => !headingTypes.has(t.type))
    const phases: Phase[] = []

    // Phase 1: headings fade in together — factory captures element refs at play-time
    if (headings.length > 0) {
      const headingTokens = headings
      phases.push({
        tokens: headings,
        durationMs: 900,
        animation: () => {
          const els = this.els(headingTokens)
          return animate(els, { opacity: [0, 1] }, { duration: 0.9, easing: 'ease-out' })
        },
        autoAdvanceMs: 500,
        persist: true,
      })
    }

    // Phase 2+: each body element individually, in markdown order
    for (const token of body) {
      const t = token
      const durMs = Math.round(this.durationFor(t) * 1000)
      phases.push({
        tokens: [token],
        durationMs: durMs,
        animation: () => {
          const el = this.el(t.index)
          if (!el) return animate(document.createElement('div'), { opacity: [0, 1] }, { duration: 0.001 })
          return animate(el, { opacity: [0, 1] }, { duration: this.durationFor(t), easing: 'ease-out' })
        },
        autoAdvanceMs: this.pauseAfter(token),
        persist: true,
      })
    }

    if (phases.length === 0) {
      return { phases: [this.instantPhase(tokens, null)] }
    }

    return { phases }
  }

  private durationFor(token: Token): number {
    if (token.type === 'p') return Math.min(1.2, Math.max(0.6, token.text.length / 80))
    if (token.type === 'li') return 0.6
    if (token.type === 'blockquote') return 0.8
    return 0.6
  }

  private pauseAfter(token: Token): number {
    if (token.type === 'p') return Math.min(3000, Math.max(1000, token.text.length * 22))
    if (token.type === 'li') return 700
    if (token.type === 'blockquote') return 1400
    return 800
  }

  private scaleClass(charCount: number): string {
    if (charCount < 60)  return 'scale-xl'
    if (charCount < 160) return 'scale-lg'
    if (charCount < 320) return 'scale-md'
    if (charCount < 600) return 'scale-sm'
    return 'scale-xs'
  }
}

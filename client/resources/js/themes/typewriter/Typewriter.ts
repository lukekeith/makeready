import { ThemeBase } from '../base/ThemeBase'
import type { Sequence, Token, Phase, ThemeContext } from '../base/types'
import './typewriter.scss'

/**
 * Typewriter
 *
 * Characters are revealed one-by-one with a blinking cursor.
 * Each token is its own phase. Auto-scales typography based on
 * content length. Scrolls up when content overflows the container.
 *
 * List items preserve their markdown numbers (ordered) or show
 * bullets (unordered) via CSS — the typewriter effect only types
 * the text content, not the number prefix.
 */
export class Typewriter extends ThemeBase {
  readonly name = 'Typewriter'
  readonly slug = 'typewriter'
  readonly description = 'Deliberate character-by-character reveal with monospace font'

  private trackWrap: HTMLElement | null = null
  /** Per-token cumulative timing curves for natural typing rhythm */
  private timingCache = new Map<number, number[]>()

  override mount(context: ThemeContext): void {
    super.mount(context)
    const container = context.container
    container.classList.add('theme-typewriter-container')
    const totalChars = context.tokens.reduce((n, t) => n + t.text.length, 0)
    container.classList.add(this.scaleClass(totalChars))
  }

  override afterRender(): void {
    this.hideAllTokens()

    // Wrap phases in a track for scroll-up
    const container = this.context?.container
    if (!container) return

    const wrap = document.createElement('div')
    wrap.className = 'tw-track'
    const phases = Array.from(container.querySelectorAll('.ThemePlayer__phase'))
    phases.forEach(phase => wrap.appendChild(phase))
    container.appendChild(wrap)
    this.trackWrap = wrap
  }

  override unmount(): void {
    const container = this.context?.container
    if (!container) return
    container.classList.remove('theme-typewriter-container')
    container.className = container.className
      .replace(/\bscale-\S+/g, '')
      .trim()
    this.trackWrap = null
    this.timingCache.clear()
  }

  override seekTo(phaseIndex: number, progress: number): void {
    const seq = this.lastSequence
    if (!seq) return
    const phase = seq.phases[phaseIndex]
    if (!phase) return

    for (const token of phase.tokens) {
      const el = this.el(token.index)
      if (!el) continue
      el.style.opacity = '1'

      const curve = this.getTimingCurve(token)
      const charCount = this.charsAtProgress(curve, progress)

      el.innerHTML = token.text.slice(0, charCount)
      if (progress < 1) {
        el.innerHTML += '<span class="tw-cursor"></span>'
      }
    }

    this.scrollTrack(phaseIndex)
  }

  /**
   * Build (and cache) a cumulative timing curve for a token's text.
   * Each entry is the cumulative "time weight" after typing that character.
   * Normalized to 0–1 so we can map progress directly.
   *
   * Weights simulate natural typing rhythm:
   *  - Spaces: very fast (end of a word, finger hits spacebar quickly)
   *  - Characters inside short words (1-3 chars): fast (common words)
   *  - Characters inside medium words (4-6 chars): normal
   *  - Characters inside long words (7+ chars): slower
   *  - After punctuation (.,;:!?): brief pause
   *  - After sentence-ending punctuation (. ! ?): longer pause
   *  - First char of a new word after a pause: slight hesitation
   */
  private getTimingCurve(token: Token): number[] {
    const cached = this.timingCache.get(token.index)
    if (cached) return cached

    const text = token.text
    const weights: number[] = []
    const words = text.split(/(\s+)/)

    let pos = 0
    for (const segment of words) {
      if (/^\s+$/.test(segment)) {
        // Whitespace — very fast
        for (let i = 0; i < segment.length; i++) {
          weights[pos++] = 0.3
        }
      } else {
        // Word
        const wordLen = segment.length
        for (let i = 0; i < segment.length; i++) {
          const ch = segment[i]
          const prevCh = i > 0 ? segment[i - 1] : ''

          // Base weight depends on word length
          let w: number
          if (wordLen <= 3) w = 0.6       // short words: fast
          else if (wordLen <= 6) w = 1.0   // medium words: normal
          else w = 1.3                     // long words: slower

          // First character of a word: slight hesitation
          if (i === 0) w += 0.3

          // After sentence-ending punctuation: longer pause
          if (/[.!?]/.test(prevCh)) w += 2.0
          // After other punctuation: brief pause
          else if (/[,;:\-—]/.test(prevCh)) w += 0.8

          // Uppercase (start of sentence): tiny pause
          if (ch >= 'A' && ch <= 'Z' && i === 0) w += 0.2

          weights[pos++] = w
        }
      }
    }

    // Build cumulative curve normalized to 0–1
    if (weights.length === 0) {
      this.timingCache.set(token.index, [])
      return []
    }

    const cumulative: number[] = []
    let sum = 0
    for (let i = 0; i < weights.length; i++) {
      sum += weights[i]
      cumulative[i] = sum
    }
    // Normalize
    for (let i = 0; i < cumulative.length; i++) {
      cumulative[i] /= sum
    }

    this.timingCache.set(token.index, cumulative)
    return cumulative
  }

  /**
   * Given a normalized timing curve and a progress (0–1),
   * return how many characters should be visible.
   */
  private charsAtProgress(curve: number[], progress: number): number {
    if (curve.length === 0) return 0
    if (progress >= 1) return curve.length
    if (progress <= 0) return 0

    // Binary search for the first index where curve[i] >= progress
    let lo = 0, hi = curve.length - 1
    while (lo < hi) {
      const mid = (lo + hi) >> 1
      if (curve[mid] < progress) lo = mid + 1
      else hi = mid
    }
    return lo + 1  // +1 because we want chars visible up to this point
  }

  buildSequence(): Sequence {
    const { tokens, prefersReducedMotion } = this.context

    if (prefersReducedMotion) {
      return { phases: [this.instantPhase(tokens, 0)] }
    }

    const phases: Phase[] = []

    for (const token of tokens) {
      const durationMs = this.durationFor(token)
      phases.push({
        tokens: [token],
        durationMs,
        animation: null,  // driven by seekTo via the clock
        autoAdvanceMs: this.pauseAfter(token),
        persist: true,
      })
    }

    return { phases }
  }

  /** See GentleFade.scrollTrack for the math — same problem, same fix. */
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

  private durationFor(token: Token): number {
    switch (token.type) {
      case 'h1': return 1200
      case 'h2': return 900
      case 'h3': return 700
      default:   return Math.min(2000, Math.max(600, token.text.length * 22))
    }
  }

  private pauseAfter(token: Token): number {
    if (token.type === 'h1') return 600
    if (token.type === 'h2' || token.type === 'h3') return 400
    if (token.type === 'li') return 200
    if (token.type === 'blockquote') return 600
    return Math.min(1500, Math.max(300, token.text.length * 12))
  }

  private scaleClass(charCount: number): string {
    if (charCount < 60)  return 'scale-xl'
    if (charCount < 160) return 'scale-lg'
    if (charCount < 320) return 'scale-md'
    if (charCount < 600) return 'scale-sm'
    return 'scale-xs'
  }
}

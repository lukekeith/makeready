import { animate } from 'motion'
import { ThemeBase } from '../base/ThemeBase'
import type { Sequence, ThemeContext } from '../base/types'
import './no-theme.scss'

/**
 * No Theme — fade in with natural scrolling. Designed for large amounts of text.
 * Content fades in together over 1s; the container scrolls natively.
 */
export class NoTheme extends ThemeBase {
  readonly name = 'No Theme'
  readonly slug = 'none'
  readonly description = 'Designed for large amounts of text'

  override mount(context: ThemeContext): void {
    super.mount(context)
    const container = context.container
    container.classList.add('theme-no-theme-container')
    const totalChars = context.tokens.reduce((n, t) => n + t.text.length, 0)
    container.classList.add(this.scaleClass(totalChars))
    container.style.opacity = '0'
  }

  override afterRender(): void {
    // Tokens default to opacity:0 in ThemePlayer.scss. We fade the whole
    // container instead, so reveal each token first.
    for (const token of this.context.tokens) {
      const el = this.el(token.index)
      if (el) el.style.opacity = '1'
    }
  }

  override unmount(): void {
    const container = this.context?.container
    if (!container) return
    container.classList.remove('theme-no-theme-container')
    container.className = container.className
      .replace(/\bscale-\S+/g, '')
      .trim()
    container.style.opacity = ''
  }

  override seekTo(_phaseIndex: number, progress: number): void {
    const container = this.context?.container
    if (container) container.style.opacity = String(progress)
  }

  buildSequence(): Sequence {
    const { tokens, container, prefersReducedMotion } = this.context

    if (prefersReducedMotion) {
      container.style.opacity = '1'
      return { phases: [this.instantPhase(tokens, null)] }
    }

    return {
      phases: [{
        tokens,
        durationMs: 1000,
        animation: () => animate(
          container,
          { opacity: [0, 1] },
          { duration: 1, easing: 'ease-out' }
        ),
        autoAdvanceMs: null,
        persist: true,
      }],
    }
  }

  private scaleClass(charCount: number): string {
    if (charCount < 60)  return 'scale-xl'
    if (charCount < 160) return 'scale-lg'
    if (charCount < 320) return 'scale-md'
    if (charCount < 600) return 'scale-sm'
    return 'scale-xs'
  }
}

import { ThemeBase } from '../base/ThemeBase'
import type { Sequence, ThemeContext } from '../base/types'
import type { AnimationPlaybackControls } from 'motion'
import './star-wars.scss'

/**
 * Star Wars
 *
 * Classic perspective crawl — all tokens rendered together as one
 * continuous block that scrolls from below the viewport to above it.
 *
 * This theme mounts its own crawl DOM in mount() and hides the
 * player's default token elements. The single phase's animation
 * is the rAF-based scroll. Tapping stops it (snap to end = done).
 */
export class StarWars extends ThemeBase {
  readonly name = 'Star Wars'
  readonly slug = 'star-wars'
  readonly description = 'Continuous scroll-up crawl — classic perspective-tilt text roll'
  readonly ownsRendering = true   // player skips default token rendering

  private crawlEl: HTMLElement | null = null
  private raf: number | null = null

  override mount(context: ThemeContext): void {
    super.mount(context)

    const container = context.container
    container.classList.add('theme-star-wars-container')

    // Build crawl container with full HTML content
    const crawl = document.createElement('div')
    crawl.className = 'theme-star-wars-crawl'

    for (const token of context.tokens) {
      const tag = this.tagFor(token.type)
      const el = document.createElement(tag)

      if (token.type === 'li' && token.listNumber != null) {
        el.innerHTML = `<span class="sw-item-num">${token.listNumber}.</span> ${token.html}`
      } else if (token.type === 'li') {
        el.innerHTML = `<span class="sw-item-bullet">&bull;</span> ${token.html}`
      } else {
        el.innerHTML = token.html
      }

      crawl.appendChild(el)
    }

    container.appendChild(crawl)
    this.crawlEl = crawl
  }

  /**
   * After the DOM is live, measure actual dimensions and update
   * the phase durationMs so the timeline matches the real crawl length.
   */
  override afterRender(): void {
    if (!this.crawlEl || !this.context || !this.lastSequence) return

    const container = this.context.container
    const viewportH = container.getBoundingClientRect().height || container.offsetHeight || 600
    const contentH = this.crawlEl.scrollHeight
    const totalTravel = viewportH + contentH + viewportH * 0.25
    const durationMs = Math.round((totalTravel / 67.5) * 1000)

    // Update the phase with the real measured duration
    if (this.lastSequence.phases.length > 0) {
      this.lastSequence.phases[0].durationMs = durationMs
    }
  }

  override unmount(): void {
    this.stopRaf()
    const container = this.context?.container
    if (!container) return

    container.classList.remove('theme-star-wars-container')
    this.crawlEl?.remove()
    this.crawlEl = null
  }

  buildSequence(): Sequence {
    const { prefersReducedMotion, container } = this.context

    if (prefersReducedMotion || !this.crawlEl) {
      return { phases: [this.instantPhase(this.context.tokens, 0)] }
    }

    // Measure actual content height if available, otherwise estimate
    const contentH = this.crawlEl?.scrollHeight || this.context.tokens.length * 30
    const viewportH = container.getBoundingClientRect().height || container.offsetHeight || 600
    const totalTravel = viewportH + contentH + viewportH * 0.25
    const durationMs = Math.round((totalTravel / 67.5) * 1000)

    // One phase, one animation — the full crawl
    return {
      phases: [{
        tokens: this.context.tokens,
        durationMs,
        animation: this.buildCrawlAnimation(container, this.crawlEl),
        autoAdvanceMs: 0,
        persist: true,
      }],
    }
  }

  private buildCrawlAnimation(
    container: HTMLElement,
    crawl: HTMLElement
  ): AnimationPlaybackControls {
    let resolve: (() => void) | null = null
    const finished = new Promise<void>(r => { resolve = r })
    let stopped = false

    const stop = () => {
      this.stopRaf()
      stopped = true
      resolve?.()
    }

    const play = () => {
      if (stopped) return

      // Measure at play-time (after DOM has rendered) for accurate dimensions
      const viewportH = container.getBoundingClientRect().height || container.offsetHeight || 600
      const contentH = crawl.scrollHeight

      // Start: fully below the viewport bottom
      const startY = viewportH
      // End: content just clears the top — with rotateX(12deg) perspective,
      // text vanishes well before reaching the top edge, so a small overshoot suffices
      const endY = -(contentH + viewportH * 0.25)
      const totalTravel = startY - endY

      // ~67.5px/s — slow, cinematic Star Wars pace
      const durationMs = (totalTravel / 67.5) * 1000
      const startTime = performance.now()

      crawl.style.transform = `rotateX(12deg) translateY(${startY}px)`

      const tick = (now: number) => {
        const progress = Math.min((now - startTime) / durationMs, 1)
        const y = startY + (endY - startY) * progress
        crawl.style.transform = `rotateX(12deg) translateY(${y}px)`

        if (progress < 1) {
          this.raf = requestAnimationFrame(tick)
        } else {
          this.raf = null
          resolve?.()
        }
      }

      this.raf = requestAnimationFrame(tick)
    }

    return {
      play, stop,
      pause: stop, cancel: stop, complete: stop,
      get finished() { return finished as unknown as Promise<any> },
      get duration() { return 0 },
      get time() { return 0 },
      set time(_v) {},
      get speed() { return 1 },
      set speed(_v) {},
      get state() { return 'idle' as const },
      then(onFulfilled: any, onRejected: any) {
        return finished.then(onFulfilled, onRejected) as any
      },
    } as unknown as AnimationPlaybackControls
  }

  /**
   * Render the crawl at a given progress (0–1).
   * progress 0 = text fully below viewport, 1 = fully scrolled off top.
   */
  override seekTo(_phaseIndex: number, progress: number): void {
    if (!this.crawlEl || !this.context) return

    const container = this.context.container
    const viewportH = container.getBoundingClientRect().height || container.offsetHeight || 600
    const contentH = this.crawlEl.scrollHeight

    const startY = viewportH
    const endY = -(contentH + viewportH * 0.25)
    const y = startY + (endY - startY) * progress

    this.crawlEl.style.transform = `rotateX(12deg) translateY(${y}px)`
  }

  private stopRaf() {
    if (this.raf !== null) {
      cancelAnimationFrame(this.raf)
      this.raf = null
    }
  }

  private tagFor(type: string): string {
    if (type === 'h1') return 'h1'
    if (type === 'h2') return 'h2'
    if (type === 'h3') return 'h3'
    if (type === 'h4') return 'h4'
    if (type === 'li') return 'p'     // treat as paragraph in crawl
    if (type === 'blockquote') return 'blockquote'
    return 'p'
  }
}

export interface Token {
  type: string       // 'h1', 'h2', 'h3', 'h4', 'p', 'li', 'blockquote', 'verse', 'verse-reference'
  text?: string      // Raw text content
  html?: string      // HTML content for inline formatting
  number?: number    // Verse number (for verse tokens)
  depth?: number     // Heading depth
  children?: Token[] // Nested tokens (for lists)
}

export interface Phase {
  tokens: Token[]
  display?: 'fullscreen' | 'centered' | undefined
  pauseAfter: boolean
  stagger?: number
}

export interface SpringEasing {
  type: 'spring'
  stiffness?: number
  damping?: number
}

/**
 * Animation type identifiers.
 *
 * Standard:   fade | slide-up | slide-down | slide-left | slide-right
 *             scale | blur | clip-reveal | spring
 * Text-level: typewriter       — char-by-char reveal
 *             word-by-word     — word stagger within a token
 *             line-by-line     — line stagger within a token
 * Motion:     scroll-up        — continuous Star Wars crawl
 *             zoom-in          — scale from 0.6 to 1
 *             glow             — opacity + text-shadow glow pulse
 * None:       none             — instant appear, no animation
 */
export type AnimationType =
  | 'fade'
  | 'slide-up' | 'slide-down' | 'slide-left' | 'slide-right'
  | 'scale' | 'zoom-in'
  | 'blur' | 'glow'
  | 'clip-reveal'
  | 'spring'
  | 'typewriter'
  | 'word-by-word'
  | 'line-by-line'
  | 'scroll-up'
  | 'none'

export interface EnterConfig {
  type: AnimationType
  duration: number
  easing?: string | SpringEasing
  /** Stagger delay between elements in a group (ms) */
  stagger?: number
  /** Stagger delay between words — used with word-by-word (ms) */
  wordStagger?: number
  /** Stagger delay between lines — used with line-by-line (ms) */
  lineStagger?: number
  /** Slide distance in px (slide-* types) */
  distance?: number
  /** Initial delay before animation starts (ms) */
  delay?: number
}

export interface ExitConfig {
  type: AnimationType
  duration: number
  easing?: string | SpringEasing
}

export interface BlockTransition {
  /** How the current phase exits before the next phase enters */
  type: 'fade' | 'slide-left' | 'slide-right' | 'zoom-out' | 'none'
  duration: number
}

export interface ElementConfig {
  style?: Record<string, any>
  enter?: EnterConfig
  exit?: ExitConfig | null
  /** 'fullscreen' — phase takes full viewport. 'centered' — horizontally + vertically centered. */
  display?: 'fullscreen' | 'centered'
  /** Text alignment override */
  align?: 'left' | 'center' | 'right'
  /** Max width for this element, e.g. '80%' or '600px' */
  width?: string
}

export interface SequenceRule {
  match: string
  phase: 'solo' | 'group'
  stagger?: number
  pauseAfter?: boolean
  /** Minimum ms to display this phase before auto-advancing (overrides global autoPlayDelay) */
  minDisplayDuration?: number
  /** Transition to play when exiting this phase */
  transition?: BlockTransition
}

export interface ThemeBackground {
  color: string
  image?: string | null
  /** CSS background-size value for the image */
  imageObjectFit?: 'cover' | 'contain' | 'fill'
  /** Opacity of the background image layer (0–1) */
  imageOpacity?: number
  video?: string | null
  /** CSS gradient or rgba string applied on top of image/video */
  overlay?: string | null
  /** Blur applied to the background image (px) */
  blur?: number
}

export interface ThemeTypography {
  fontFamily: string
  fontSize: number
  color: string
  lineHeight: number
}

export interface ThemeInteraction {
  /** 'tap-to-advance' | 'auto-play' | 'timed' | 'swipe' */
  mode: string
  autoPlayDelay?: number | null
  /** Allow tap to advance even in auto-play mode */
  tapAdvances?: boolean
  /** Allow swipe to advance (iOS) */
  swipeAdvances?: boolean
  showProgress: boolean
  /** Progress indicator style */
  progressStyle?: 'dots' | 'bar' | 'numbers'
  /** Show the read block's title above the phase */
  showBlockTitle?: boolean
}

export interface ThemeDefinition {
  version: number
  /** Controls whether multiple read blocks display sequentially or all at once */
  readBlockSequencing?: 'sequential' | 'all-at-once'
  background: ThemeBackground
  interaction: ThemeInteraction
  typography: ThemeTypography
  elements: Record<string, ElementConfig>
  sequences: SequenceRule[]
}

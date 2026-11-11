import { describe, it, expect } from 'vitest'
import { normalizeVerseText } from '../verse-text.js'

describe('verse-text', () => {
  it('normalizeVerseText cleans pilcrows, breaks, escapes and runs', () => {
    expect(normalizeVerseText('¶ For God\r\nso  loved\\nthe\\rworld \n')).toBe('For God so loved the world')
    expect(normalizeVerseText('  plain  ')).toBe('plain')
  })
})

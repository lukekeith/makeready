import { describe, expect, it } from 'vitest'
import {
  isStableNumberedScriptureMarkdown,
  normalizeScriptureMarkdown,
  normalizeScriptureVerses,
} from '../scripture-content-normalizer.js'

describe('scripture-content-normalizer', () => {
  it('normalizes markdown verse whitespace', () => {
    const input = '1. In the beginning\nGod created    the heavens\n\nand the earth.\n2. The earth was\twithout form and void.'

    expect(normalizeScriptureMarkdown(input)).toBe(
      '1. In the beginning God created the heavens and the earth.\n' +
        '2. The earth was without form and void.'
    )
  })

  it('normalizes HTML verse content', () => {
    const input = '<p><sup>1</sup>&nbsp;In the beginning<br>God created &amp; formed.</p><p><sup>2</sup> The earth was void.</p>'

    expect(normalizeScriptureMarkdown(input)).toBe(
      '1. In the beginning God created & formed.\n' +
        '2. The earth was void.'
    )
  })

  it('normalizes escaped newlines and entities', () => {
    const input = '1. In&nbsp;the beginning\\nGod created.\\r\\n2. The earth&#39;s form was void.'

    expect(normalizeScriptureMarkdown(input)).toBe(
      "1. In the beginning God created.\n2. The earth's form was void."
    )
  })

  it('does not require a passage to start at verse one', () => {
    const input = '3. Blessed are the poor in spirit.\n4. Blessed are those who mourn.'

    expect(normalizeScriptureMarkdown(input)).toBe(
      '3. Blessed are the poor in spirit.\n4. Blessed are those who mourn.'
    )
  })

  it('does not treat ordinary numbers inside verse text as verse markers', () => {
    const input = '10. The 12 disciples gathered in 1 place.\n11. Then they continued.'

    expect(normalizeScriptureMarkdown(input)).toBe(
      '10. The 12 disciples gathered in 1 place.\n11. Then they continued.'
    )
  })

  it('normalizes legacy superscript verse markers', () => {
    const input = '¹ In the beginning God created. ² The earth was without form.'

    expect(normalizeScriptureMarkdown(input)).toBe(
      '1. In the beginning God created.\n2. The earth was without form.'
    )
  })

  it('falls back to collapsed plain text when no verse markers exist', () => {
    const input = '<p>In the beginning\nGod created&nbsp;&nbsp;the heavens.</p>'

    expect(normalizeScriptureMarkdown(input)).toBe('In the beginning God created the heavens.')
  })

  it('formats verse arrays as normalized markdown', () => {
    expect(normalizeScriptureVerses([
      { verse: 1, text: ' In the beginning\nGod created. ' },
      { verse: 2, text: 'The earth&nbsp;was void.' },
    ])).toBe('1. In the beginning God created.\n2. The earth was void.')
  })

  it('detects stable numbered markdown', () => {
    expect(isStableNumberedScriptureMarkdown('1. In the beginning.\n2. The earth was void.')).toBe(true)
    expect(isStableNumberedScriptureMarkdown('1 In the beginning.\n2 The earth was void.')).toBe(false)
  })
})

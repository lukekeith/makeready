import { describe, expect, it } from 'vitest'
import { deriveTitlePreview } from '../note-title.js'

describe('deriveTitlePreview', () => {
  it('title is the first stripped line and preview the next', () => {
    expect(deriveTitlePreview('# Hello **world**\n\nSecond *line*\nthird')).toEqual({ title: 'Hello world', preview: 'Second line' })
    expect(deriveTitlePreview(' \n\n ')).toEqual({ title: null, preview: null })
  })

  it('blank and markup-only lines are skipped, list markers dropped', () => {
    expect(deriveTitlePreview('\n\n**\n- one\n\n1. two')).toEqual({ title: 'one', preview: 'two' })
  })

  it('underline, strike, highlight markers removed and escapes undone', () => {
    expect(deriveTitlePreview('<u>a</u> ~~b~~ ==c==\nPrice \\*not\\* bold')).toEqual({ title: 'a b c', preview: 'Price *not* bold' })
  })

  it('decodes the codec\'s edge-whitespace references before trimming', () => {
    expect(deriveTitlePreview('Sunday sermon&#32;\n&#9;indented&#32;&#9;')).toEqual({ title: 'Sunday sermon', preview: 'indented' })
    expect(deriveTitlePreview('&#32;\nreal')).toEqual({ title: 'real', preview: null })
    expect(deriveTitlePreview('a &#32;b')).toEqual({ title: 'a  b', preview: null })
  })

  it('the cut is 120 code points and never splits a surrogate pair', () => {
    const { title } = deriveTitlePreview('😀'.repeat(130))
    expect(Array.from(title!)).toHaveLength(120)
    expect(title).toBe('😀'.repeat(120))
  })
})

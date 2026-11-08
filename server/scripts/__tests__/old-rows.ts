/** One old-model activity fixture per row of activity-viewer 05 s6's conversion table (shared by the convert and import tests). */
import type { OldActivity, OldBlock } from '../content-convert.js'

const block = (over: Partial<OldBlock> & { id: string }): OldBlock => ({
  orderNumber: 1, title: null, content: null, isLocked: false, contentFormat: 'markdown',
  sourceReferenceId: null, backgroundImageUrl: null, backgroundColor: null, backgroundOverlayOpacity: null,
  fontSize: null, highlights: [], ...over,
})

const base = (over: Partial<OldActivity> & { id: string; activityType: string }): OldActivity => ({
  orderNumber: 1, title: 'Activity', readBlocks: [], sourceReferences: [], ...over,
})

export const OLD_ROWS: { name: string; old: OldActivity; expectKinds: string[] }[] = [
  {
    name: 'VIDEO',
    old: base({ id: 'old-video', activityType: 'VIDEO', title: 'Watch', videoId: 'video-1' }),
    expectKinds: ['video'],
  },
  {
    name: 'YOUTUBE',
    old: base({
      id: 'old-youtube', activityType: 'YOUTUBE', title: 'Clip',
      youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', youtubeVideoId: 'dQw4w9WgXcQ',
      youtubeStartSeconds: 5, youtubeEndSeconds: 60,
    }),
    expectKinds: ['youtube'],
  },
  {
    name: 'USER_INPUT',
    old: base({
      id: 'old-write', activityType: 'USER_INPUT', title: 'Observation',
      helpTitle: 'Look closely', helpDescription: 'What stands out?', placeholder: 'Write here',
    }),
    expectKinds: ['write'],
  },
  {
    name: 'EXEGESIS',
    old: base({
      id: 'old-exegesis', activityType: 'EXEGESIS', title: 'Romans 1',
      sourceReferences: [{
        id: 'sr1', sourceType: 'SCRIPTURE', passageReference: 'Romans 1:1-2', bookNumber: 45,
        chapterStart: 1, chapterEnd: 1, verseStart: 1, verseEnd: 2,
      }],
      readBlocks: [block({
        id: 'b1', title: 'Romans 1:1-2', isLocked: true, sourceReferenceId: 'sr1',
        content: '1 Paul, a servant of Christ Jesus, called to be an apostle.\n2 Which he promised beforehand.',
        highlights: [
          { orderNumber: 1, start: 2, end: 6, noteMarkdown: 'Paul wrote this', style: 'highlight' },
          { orderNumber: 2, start: 10, end: 17, noteMarkdown: '', style: 'bold' },
        ],
      })],
    }),
    expectKinds: ['bible'],
  },
  {
    name: 'READ locked scripture block',
    old: base({
      id: 'old-read-locked', activityType: 'READ', title: 'Psalm 23',
      sourceReferences: [{
        id: 'sr2', sourceType: 'SCRIPTURE', passageReference: 'Psalm 23:1', bookNumber: 19,
        chapterStart: 23, chapterEnd: 23, verseStart: 1, verseEnd: 1,
      }],
      readBlocks: [block({ id: 'b2', title: 'Psalm 23:1', isLocked: true, sourceReferenceId: 'sr2', content: '1 The Lord is my shepherd.' })],
    }),
    expectKinds: ['bible'],
  },
  {
    name: 'READ unstyled text blocks',
    old: base({
      id: 'old-read-text', activityType: 'READ', title: 'Context',
      readBlocks: [
        block({ id: 'b3', orderNumber: 1, content: '# Background\n\nPaul wrote **to the Romans** from *Corinth*. See [notes](https://example.com).', fontSize: 'lg' }),
        block({ id: 'b4', orderNumber: 2, content: '- first\n- second' }),
      ],
    }),
    expectKinds: ['text'],
  },
  {
    name: 'READ block with its own background',
    old: base({
      id: 'old-read-bg', activityType: 'READ', title: 'Mixed',
      readBlocks: [
        block({ id: 'b5', orderNumber: 1, content: 'Intro text' }),
        block({ id: 'b6', orderNumber: 2, content: 'On a picture', backgroundImageUrl: 'https://images.test/bg.jpg', backgroundOverlayOpacity: 0.5 }),
        block({ id: 'b7', orderNumber: 3, content: 'On a colour', backgroundColor: '#112233', themeId: 'theme-1' }),
      ],
    }),
    expectKinds: ['text', 'text', 'text'],
  },
]

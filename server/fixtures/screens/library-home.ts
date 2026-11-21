/**
 * library-home layer (notes D19): the Fixtures leader's notes, one in each D3 bucket — today,
 * yesterday, Previous 7 Days, Previous 30 Days, an earlier month, an earlier year — newest first,
 * the today note linked to base group 1 for the context line. `empty` is base only (this layer
 * exports none). Creates no org, user or group; never touches ctx.rand; dates only from ctx.
 */
import type { FixtureContext } from '../context.js'
import { deriveTitlePreview } from '../../src/services/note-title.js'
import { FIXTURE_GROUP_IDS, FIXTURE_USER_ID, fixtureId } from '../ids.js'

const NOTES: ReadonlyArray<{ age: number | 'hour'; content: string }> = [
  { age: 'hour', content: '# Sunday sermon\nGrace is a gift, not a wage.' },
  { age: 1, content: '# Prayer list\nFamily, the group, and the week ahead.' },
  { age: 4, content: '# Romans 8 reflections\nNo condemnation for those in Christ.' },
  { age: 15, content: '# Group study ideas\nTry a five-day plan on forgiveness.' },
  { age: 45, content: '# Retreat planning\nBook the lodge and confirm the speaker.' },
  { age: 400, content: '# Last year goals\nRead through the Gospels slowly.' },
]

export function libraryHomeRows(now: Date, daysAgo: (n: number) => Date) {
  const notes = NOTES.map((spec, i) => {
    const at = spec.age === 'hour' ? new Date(now.getTime() - 3_600_000) : daysAgo(spec.age)
    return {
      id: fixtureId('studyNote', i + 1),
      userId: FIXTURE_USER_ID,
      type: 'NOTE',
      content: spec.content,
      ...deriveTitlePreview(spec.content),
      createdAt: at,
      updatedAt: at,
    }
  })
  const links = [
    { id: fixtureId('studyNote', 1001), noteId: notes[0].id, refType: 'GROUP', refId: FIXTURE_GROUP_IDS[0], createdAt: notes[0].createdAt },
  ]
  return { notes, links }
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { notes, links } = libraryHomeRows(ctx.now, (n) => ctx.daysAgo(n))
  await ctx.prisma.studyNote.createMany({ data: notes })
  await ctx.prisma.noteLink.createMany({ data: links })
}

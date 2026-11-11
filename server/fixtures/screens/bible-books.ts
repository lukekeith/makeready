/**
 * bible-books layer (bible-verse-picker Task 4): the six recent Bible searches Books shows under the search field,
 * for the fixture user, newest first. `bible-chapters` and `bible-verses` read no server rows beyond the "used"
 * passages `bible-reader.ts` seeds (D16); their screen specs cite that layer. Reads only base ids, never touches
 * ctx.rand, creates no org, user or group.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_USER_ID } from '../ids.js'

export const BIBLE_RECENT_QUERIES = ['john 3:16', 'grace', 'Psalm 23', 'love one another', 'Romans 8', 'faith']

export async function full(ctx: FixtureContext): Promise<void> {
  await ctx.prisma.searchHistory.createMany({
    data: BIBLE_RECENT_QUERIES.map((query, i) => ({
      userId: FIXTURE_USER_ID,
      query,
      searchType: 'bible',
      resultCount: 10,
      createdAt: ctx.daysAgo(i + 1),
    })),
  })
}

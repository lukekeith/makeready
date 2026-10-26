import { describe, expect, it } from 'vitest'
import { FIXTURE_LEADER_EMAIL, FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_EMAIL, FIXTURE_USER_ID } from '../ids.js'
import { type WipeClient, fixtureUserExists, wipeFixtures } from '../wipe.js'

describe('wipeFixtures (D7)', () => {
  it('deletes exactly the fixture graph, in the D7 order', async () => {
    const calls: Array<{ model: string; args: unknown }> = []
    const model = (name: string) => ({
      deleteMany: async (args: unknown) => {
        calls.push({ model: name, args })
        return { count: 0 }
      },
    })
    const fake = {
      clientEvent: model('clientEvent'),
      member: model('member'),
      group: model('group'),
      studyProgram: model('studyProgram'),
      user: model('user'),
    } as unknown as WipeClient

    await wipeFixtures(fake)

    expect(calls).toEqual([
      {
        model: 'clientEvent',
        args: { where: { OR: [{ organizationId: FIXTURE_ORG_ID }, { memberId: { in: FIXTURE_MEMBER_IDS } }] } },
      },
      { model: 'member', args: { where: { id: { in: FIXTURE_MEMBER_IDS } } } },
      { model: 'group', args: { where: { organizationId: FIXTURE_ORG_ID } } },
      { model: 'studyProgram', args: { where: { organizationId: FIXTURE_ORG_ID } } },
      { model: 'user', args: { where: { id: { in: [FIXTURE_USER_ID, FIXTURE_LEADER_USER_ID] } } } },
    ])
  })

  it('seed refuses when either fixture user exists, by id or by email', async () => {
    let args: unknown
    const fake = {
      user: {
        findFirst: async (a: unknown) => {
          args = a
          return null
        },
      },
    } as unknown as Parameters<typeof fixtureUserExists>[0]
    expect(await fixtureUserExists(fake)).toBe(false)
    expect(args).toEqual({
      where: {
        OR: [
          { id: { in: [FIXTURE_USER_ID, FIXTURE_LEADER_USER_ID] } },
          { email: { in: [FIXTURE_USER_EMAIL, FIXTURE_LEADER_EMAIL] } },
        ],
      },
      select: { id: true },
    })
  })
})

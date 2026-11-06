import { describe, expect, it } from 'vitest'
import { FIXTURE_NEW_GROUP_ORG_ID, FIXTURE_NEW_GROUP_USER_ID } from '../ids.js'
import { wipeNewGroup } from '../new-group.js'

describe('wipeNewGroup (§server Runner)', () => {
  it('wipeNewGroup deletes in the spec\'s order and never members', async () => {
    const calls: Array<{ model: string; args: unknown }> = []
    const model = (name: string) => ({ deleteMany: async (args: unknown) => { calls.push({ model: name, args }); return { count: 0 } } })
    const fake = { clientEvent: model('clientEvent'), group: model('group'), studyProgram: model('studyProgram'), lessonTemplate: model('lessonTemplate'), user: model('user') }
    await wipeNewGroup(fake as never)
    const org = { where: { organizationId: FIXTURE_NEW_GROUP_ORG_ID } }
    expect(calls).toEqual([
      { model: 'clientEvent', args: org },
      { model: 'group', args: org },
      { model: 'studyProgram', args: org },
      { model: 'lessonTemplate', args: org },
      { model: 'user', args: { where: { id: FIXTURE_NEW_GROUP_USER_ID } } },
    ])
  })
})

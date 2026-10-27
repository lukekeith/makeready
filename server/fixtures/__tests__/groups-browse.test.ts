import { describe, expect, it } from 'vitest'
import { ALL_DAYS, ENROLLMENT_PLAN, EMPTY_GROUP_NAME, MEMBERS_PER_GROUP, lessonOffsets, scheduleId } from '../base.js'
import { localDate } from '../context.js'
import { FIXTURE_EMPTY_GROUP_ID, FIXTURE_GROUP_IDS, FIXTURE_KIND, FIXTURE_LEADER_GROUP_ID, fixtureId } from '../ids.js'
import {
  GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS,
  LEFT_MEMBER_INDEX,
  NEXT_LESSON_SCHEDULE_IDS,
  REQUESTER_INDICES,
  RICH_GROUP_ID,
} from '../screens/groups-detail.js'

describe('groups-browse fixture ids (D19, D25)', () => {
  it('adds the Empty Group as group 5, apart from the base and leader groups', () => {
    expect(FIXTURE_EMPTY_GROUP_ID).toBe(fixtureId('group', 5))
    expect([...FIXTURE_GROUP_IDS, FIXTURE_LEADER_GROUP_ID]).not.toContain(FIXTURE_EMPTY_GROUP_ID)
    expect(EMPTY_GROUP_NAME).toBe('Empty Group')
  })

  it('gives every kind a distinct code', () => {
    const codes = Object.values(FIXTURE_KIND)
    expect(new Set(codes).size).toBe(codes.length)
    expect(FIXTURE_KIND).toMatchObject({
      joinRequest: '0015',
      feedActivity: '0016',
      event: '0017',
      scheduledActivity: '0018',
      video: '0019',
      readBlock: '001a',
    })
  })

  it('puts the next lesson on enrollment 4 (group 1) today and tomorrow', () => {
    const e4 = ENROLLMENT_PLAN[3]
    expect(e4.index).toBe(4)
    expect(FIXTURE_GROUP_IDS[e4.groupIndex]).toBe(RICH_GROUP_ID)
    const offsets = lessonOffsets(localDate(new Date()), e4.startOffset, 21, ALL_DAYS)
    expect([offsets[13], offsets[14]]).toEqual([0, 1])
    expect(NEXT_LESSON_SCHEDULE_IDS).toEqual([scheduleId(4, 14), scheduleId(4, 15)])
  })

  it('takes requesters and the leaver from outside group 1', () => {
    for (const i of [...REQUESTER_INDICES, LEFT_MEMBER_INDEX]) expect(i).toBeGreaterThanOrEqual(MEMBERS_PER_GROUP)
    expect(GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS).toHaveLength(4)
  })
})

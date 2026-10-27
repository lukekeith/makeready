import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  membershipEvent: { findMany: vi.fn() },
  activity: { findMany: vi.fn() },
  event: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { getGroupHistory, memberDisplayName } from '../group-history.js'

const NOW = new Date('2026-10-27T15:00:00Z')
const at = (iso: string) => new Date(iso)
const person = (firstName: string | null, lastName: string | null) => ({ firstName, lastName })

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.membershipEvent.findMany.mockResolvedValue([])
  prismaMock.activity.findMany.mockResolvedValue([])
  prismaMock.event.findMany.mockResolvedValue([])
})

describe('memberDisplayName (D15)', () => {
  it('joins first and last, trims, else Unknown', () => {
    expect(memberDisplayName(person('James', 'Carter'))).toBe('James Carter')
    expect(memberDisplayName(person('James', null))).toBe('James')
    expect(memberDisplayName(person(null, 'Carter'))).toBe('Carter')
    expect(memberDisplayName(person(null, null))).toBe('Unknown')
    expect(memberDisplayName(person('  ', ''))).toBe('Unknown')
    expect(memberDisplayName(null)).toBe('Unknown')
  })
})

describe('getGroupHistory (D15)', () => {
  it('maps membership actions to joined / left / requested with the member name highlighted', async () => {
    prismaMock.membershipEvent.findMany.mockResolvedValue([
      { id: 'me1', action: 'APPROVED', createdAt: at('2026-10-20T10:00:00Z'), member: person('James', 'Carter') },
      { id: 'me2', action: 'ADDED', createdAt: at('2026-10-19T10:00:00Z'), member: person('Emily', 'Price') },
      { id: 'me3', action: 'REJOINED', createdAt: at('2026-10-18T10:00:00Z'), member: person('Sarah', null) },
      { id: 'me4', action: 'REMOVED_GROUP', createdAt: at('2026-10-17T10:00:00Z'), member: person('Leah', 'Graham') },
      { id: 'me5', action: 'REQUESTED', createdAt: at('2026-10-16T10:00:00Z'), member: person(null, null) },
    ])
    expect(await getGroupHistory('g1', 20, NOW)).toEqual([
      { id: 'membership:me1', occurredAt: '2026-10-20T10:00:00.000Z', kind: 'member_joined', text: 'James Carter joined the group', highlight: 'James Carter' },
      { id: 'membership:me2', occurredAt: '2026-10-19T10:00:00.000Z', kind: 'member_joined', text: 'Emily Price joined the group', highlight: 'Emily Price' },
      { id: 'membership:me3', occurredAt: '2026-10-18T10:00:00.000Z', kind: 'member_joined', text: 'Sarah joined the group', highlight: 'Sarah' },
      { id: 'membership:me4', occurredAt: '2026-10-17T10:00:00.000Z', kind: 'member_left', text: 'Leah Graham left the group', highlight: 'Leah Graham' },
      { id: 'membership:me5', occurredAt: '2026-10-16T10:00:00.000Z', kind: 'join_requested', text: 'Unknown requested to join', highlight: 'Unknown' },
    ])
  })

  it('maps GROUP activity rows: CREATED, UPDATED cover, any other UPDATED', async () => {
    prismaMock.activity.findMany.mockResolvedValue([
      { id: 'a1', action: 'UPDATED', metadata: { field: 'cover' }, createdAt: at('2026-10-25T10:00:00Z') },
      { id: 'a2', action: 'UPDATED', metadata: null, createdAt: at('2026-10-24T10:00:00Z') },
      { id: 'a3', action: 'UPDATED', metadata: { field: 'name' }, createdAt: at('2026-10-23T10:00:00Z') },
      { id: 'a4', action: 'CREATED', metadata: null, createdAt: at('2026-08-01T10:00:00Z') },
    ])
    const events = await getGroupHistory('g1', 20, NOW)
    expect(events.map((e) => [e.id, e.kind, e.text, e.highlight])).toEqual([
      ['activity:a1', 'cover_updated', 'Updated cover photo', null],
      ['activity:a2', 'settings_updated', 'Updated group settings', null],
      ['activity:a3', 'settings_updated', 'Updated group settings', null],
      ['activity:a4', 'group_created', 'Created the group', null],
    ])
  })

  it('maps past events to event_held, location first, else the title', async () => {
    prismaMock.event.findMany.mockResolvedValue([
      { id: 'e1', title: 'Monthly Breakfast', locationName: 'Corner Bakery', date: at('2026-10-22T13:00:00Z') },
      { id: 'e2', title: 'Prayer Night', locationName: null, date: at('2026-10-21T01:00:00Z') },
    ])
    expect(await getGroupHistory('g1', 20, NOW)).toEqual([
      { id: 'event:e1', occurredAt: '2026-10-22T13:00:00.000Z', kind: 'event_held', text: 'Held event at Corner Bakery', highlight: 'event at Corner Bakery' },
      { id: 'event:e2', occurredAt: '2026-10-21T01:00:00.000Z', kind: 'event_held', text: 'Held event at Prayer Night', highlight: 'event at Prayer Night' },
    ])
  })

  it('merges all three sources newest first and keeps only `limit`', async () => {
    prismaMock.membershipEvent.findMany.mockResolvedValue([
      { id: 'me1', action: 'REQUESTED', createdAt: at('2026-10-26T10:00:00Z'), member: person('Ruth', 'Diaz') },
      { id: 'me2', action: 'ADDED', createdAt: at('2026-09-01T10:00:00Z'), member: person('Naomi', 'Ford') },
    ])
    prismaMock.activity.findMany.mockResolvedValue([
      { id: 'a1', action: 'UPDATED', metadata: { field: 'cover' }, createdAt: at('2026-10-24T10:00:00Z') },
    ])
    prismaMock.event.findMany.mockResolvedValue([
      { id: 'e1', title: 'Breakfast', locationName: null, date: at('2026-10-25T10:00:00Z') },
    ])
    const events = await getGroupHistory('g1', 3, NOW)
    expect(events.map((e) => e.id)).toEqual(['membership:me1', 'event:e1', 'activity:a1'])
  })

  it('queries each source scoped to the group, per D15 and F6', async () => {
    await getGroupHistory('g1', 5, NOW)
    expect(prismaMock.membershipEvent.findMany).toHaveBeenCalledWith({
      where: { groupId: 'g1', action: { in: ['APPROVED', 'ADDED', 'REJOINED', 'REMOVED_GROUP', 'REQUESTED'] } },
      orderBy: { createdAt: 'desc' },
      take: 5,
      select: { id: true, action: true, createdAt: true, member: { select: { firstName: true, lastName: true } } },
    })
    // F6: resourceType + resourceId, never Activity.groupId (posts/events carry it too).
    expect(prismaMock.activity.findMany).toHaveBeenCalledWith({
      where: { resourceType: 'GROUP', resourceId: 'g1', action: { in: ['CREATED', 'UPDATED'] } },
      orderBy: { createdAt: 'desc' },
      take: 5,
      select: { id: true, action: true, metadata: true, createdAt: true },
    })
    expect(prismaMock.event.findMany).toHaveBeenCalledWith({
      where: { groupId: 'g1', isActive: true, type: { not: 'LESSON' }, date: { lt: NOW } },
      orderBy: { date: 'desc' },
      take: 5,
      select: { id: true, title: true, locationName: true, date: true },
    })
  })
})

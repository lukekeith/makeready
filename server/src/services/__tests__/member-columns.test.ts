/**
 * ui2-members-browse SC1–SC3: Member.address, emergencyContactName,
 * emergencyContactPhone exist on the generated client and reach the
 * GET /api/members/:id payload (getMember includes every scalar column).
 */
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Prisma, type Member } from '../../generated/prisma/index.js'

const prismaMock = vi.hoisted(() => ({ member: { findUnique: vi.fn() } }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { getMember } from '../member.js'

beforeEach(() => vi.clearAllMocks())

describe('Member SC1–SC3 columns', () => {
  it('are scalar fields of the generated Member model', () => {
    expect(Object.keys(Prisma.MemberScalarFieldEnum)).toEqual(
      expect.arrayContaining(['address', 'emergencyContactName', 'emergencyContactPhone'])
    )
  })

  it('reach the getMember payload as string | null, never filtered out', async () => {
    const columns: Pick<Member, 'address' | 'emergencyContactName' | 'emergencyContactPhone'> = {
      address: '137 Oak St\nEvanston, IL 60201',
      emergencyContactName: 'Sophia Carter',
      emergencyContactPhone: '+15550200001',
    }
    prismaMock.member.findUnique.mockResolvedValue({ id: 'm1', firstName: 'James', organizations: [], ...columns })

    const result = await getMember('m1')

    expect(result.success).toBe(true)
    expect(result.data).toMatchObject(columns)
    // getMember must keep `include` (every scalar) — a `select` here would drop the new columns.
    expect(prismaMock.member.findUnique.mock.calls[0][0]).not.toHaveProperty('select')
  })

  it('reads null for a member who has none of them', async () => {
    prismaMock.member.findUnique.mockResolvedValue({
      id: 'm2',
      organizations: [],
      address: null,
      emergencyContactName: null,
      emergencyContactPhone: null,
    })
    const result = await getMember('m2')
    expect(result.data).toMatchObject({ address: null, emergencyContactName: null, emergencyContactPhone: null })
  })
})

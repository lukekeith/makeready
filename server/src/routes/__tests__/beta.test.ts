import { generateKeyPairSync, createSign, type JsonWebKey } from 'crypto'
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import request from 'supertest'

const prismaMock = vi.hoisted(() => ({
  faqItem: {
    findMany: vi.fn(),
  },
  user: {
    findFirst: vi.fn(),
  },
  $transaction: vi.fn(),
  $queryRaw: vi.fn(),
  $connect: vi.fn(),
}))

const pgMock = vi.hoisted(() => ({
  query: vi.fn().mockResolvedValue({ rows: [{ exists: true }] }),
  release: vi.fn(),
}))

vi.mock('pg', () => ({
  default: {
    Pool: vi.fn().mockImplementation(() => ({
      connect: vi.fn().mockResolvedValue(pgMock),
    })),
  },
}))

vi.mock('../../lib/prisma.js', () => ({
  prisma: prismaMock,
  Prisma: {},
}))

let app: Awaited<typeof import('../../index.js')>['app']

const { privateKey, publicKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
})
const publicJwk = publicKey.export({ format: 'jwk' }) as JsonWebKey

function base64UrlJson(value: unknown): string {
  return Buffer.from(JSON.stringify(value)).toString('base64url')
}

function signMicrosoftToken(payloadOverrides: Record<string, unknown> = {}): string {
  const header = base64UrlJson({ alg: 'RS256', kid: 'test-kid', typ: 'JWT' })
  const now = Math.floor(Date.now() / 1000)
  const payload = base64UrlJson({
    aud: 'test-microsoft-client-id',
    email: 'leader@example.org',
    exp: now + 60 * 60,
    iss: 'https://login.microsoftonline.com/test-tenant-id/v2.0',
    name: 'Beta Leader',
    nbf: now - 60,
    oid: 'microsoft-object-id-1',
    preferred_username: 'leader@example.org',
    tid: 'test-tenant-id',
    ...payloadOverrides,
  })
  const signingInput = `${header}.${payload}`
  const signer = createSign('RSA-SHA256')
  signer.update(signingInput)
  signer.end()
  return `${signingInput}.${signer.sign(privateKey).toString('base64url')}`
}

beforeAll(async () => {
  process.env.MICROSOFT_CLIENT_ID = 'test-microsoft-client-id'
  process.env.MICROSOFT_TENANT_ID = 'test-tenant-id'
  ;({ app } = await import('../../index.js'))
})

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.$queryRaw.mockResolvedValue([{ ok: 1 }])
  prismaMock.faqItem.findMany.mockResolvedValue([])
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
    ok: true,
    json: async () => ({
      keys: [{
        ...publicJwk,
        kid: 'test-kid',
        alg: 'RS256',
        use: 'sig',
      }],
    }),
  } as Response))
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('Marketing FAQ API', () => {
  it('returns active FAQs for a scope in sort order', async () => {
    prismaMock.faqItem.findMany.mockResolvedValue([
      { id: 'faq-1', scope: 'join-beta', question: 'Why Microsoft?', answer: 'Identity verification.', sortOrder: 10 },
      { id: 'faq-2', scope: 'join-beta', question: 'Is access immediate?', answer: 'No.', sortOrder: 20 },
    ])

    const response = await request(app).get('/public/faqs/join-beta')

    expect(response.status).toBe(200)
    expect(response.body).toEqual({
      success: true,
      scope: 'join-beta',
      faqs: expect.any(Array),
      count: 2,
    })
    expect(prismaMock.faqItem.findMany).toHaveBeenCalledWith({
      where: { scope: 'join-beta', isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      select: { id: true, scope: true, question: true, answer: true, sortOrder: true },
    })
  })

  it('rejects invalid FAQ scopes', async () => {
    const response = await request(app).get('/public/faqs/INVALID_SCOPE')

    expect(response.status).toBe(400)
    expect(response.body).toEqual({ success: false, error: 'Invalid FAQ scope' })
    expect(prismaMock.faqItem.findMany).not.toHaveBeenCalled()
  })
})

describe('Beta application API', () => {
  it('returns field-level validation errors before verifying Microsoft token', async () => {
    const response = await request(app)
      .post('/api/beta/applications')
      .set('User-Agent', 'Mozilla/5.0 MakeReadyTest')
      .send({
        idToken: 'not-a-token',
        organizationName: 'A',
        groupMemberAgeRange: 'Adults',
        numberOfGroups: 0,
        estimatedGroupMembers: 0,
        groupDescription: 'too short',
      })

    expect(response.status).toBe(400)
    expect(response.body.success).toBe(false)
    expect(response.body.issues).toEqual(expect.any(Array))
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('returns a Microsoft-specific auth error for invalid token shape', async () => {
    const response = await request(app)
      .post('/api/beta/applications')
      .set('User-Agent', 'Mozilla/5.0 MakeReadyTest')
      .send({
        idToken: 'not-a-token',
        organizationName: 'Example Church',
        groupMemberAgeRange: 'Adults',
        numberOfGroups: 2,
        estimatedGroupMembers: 35,
        groupDescription: 'We lead adult small groups through weekly study and daily accountability support.',
      })

    expect(response.status).toBe(401)
    expect(response.body).toEqual({ success: false, error: 'Invalid or expired Microsoft token' })
  })

  it('creates pending inactive organization and user records for a valid Microsoft token', async () => {
    const tx = {
      user: {
        findFirst: vi.fn().mockResolvedValue(null),
        create: vi.fn().mockResolvedValue({ id: 'user-1' }),
        update: vi.fn().mockResolvedValue({ id: 'user-1' }),
      },
      organization: {
        findUnique: vi.fn().mockResolvedValue(null),
        create: vi.fn().mockResolvedValue({ id: 'org-1' }),
      },
      betaApplication: {
        findFirst: vi.fn().mockResolvedValue(null),
        create: vi.fn().mockResolvedValue({
          id: 'application-1',
          status: 'PENDING',
          applicantEmail: 'leader@example.org',
          organizationName: 'Example Church',
          createdAt: new Date('2026-05-17T00:00:00Z'),
        }),
      },
    }
    prismaMock.user.findFirst.mockResolvedValue(null)
    prismaMock.$transaction.mockImplementation(async (callback: any) => callback(tx))

    const response = await request(app)
      .post('/api/beta/applications')
      .set('User-Agent', 'Mozilla/5.0 MakeReadyTest')
      .send({
        idToken: signMicrosoftToken(),
        organizationName: 'Example Church',
        organizationWebsite: 'https://example.org',
        groupMemberAgeRange: 'Adults',
        numberOfGroups: 2,
        estimatedGroupMembers: 35,
        groupDescription: 'We lead adult small groups through weekly study and daily accountability support.',
      })

    expect(response.status).toBe(201)
    expect(response.body.success).toBe(true)
    expect(response.body.application).toMatchObject({
      id: 'application-1',
      status: 'PENDING',
      applicantEmail: 'leader@example.org',
      organizationName: 'Example Church',
    })
    expect(prismaMock.user.findFirst).toHaveBeenCalledWith({
      where: {
        OR: [{ microsoftId: 'microsoft-object-id-1' }, { email: 'leader@example.org' }],
        isActive: true,
      },
      select: { id: true },
    })
    expect(tx.user.create).toHaveBeenCalledWith({
      data: {
        microsoftId: 'microsoft-object-id-1',
        email: 'leader@example.org',
        name: 'Beta Leader',
        isActive: false,
      },
    })
    expect(tx.organization.create).toHaveBeenCalledWith({
      data: {
        name: 'Example Church',
        ownerId: 'user-1',
        isActive: false,
      },
    })
    expect(tx.betaApplication.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        microsoftId: 'microsoft-object-id-1',
        applicantEmail: 'leader@example.org',
        userId: 'user-1',
        organizationId: 'org-1',
      }),
    })
  })
})

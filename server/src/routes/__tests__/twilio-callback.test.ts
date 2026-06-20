import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import request from 'supertest'

const prismaMock = vi.hoisted(() => ({
  twilioCallback: {
    create: vi.fn(),
  },
  $queryRaw: vi.fn(),
  $connect: vi.fn(),
}))

const pgMock = vi.hoisted(() => ({
  query: vi.fn().mockResolvedValue({ rows: [{ exists: true }] }),
  release: vi.fn(),
}))

const twilioMock = vi.hoisted(() => ({
  validateRequest: vi.fn(),
  validateRequestWithBody: vi.fn(),
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

vi.mock('twilio', () => ({
  default: twilioMock,
}))

let app: Awaited<typeof import('../../index.js')>['app']

const originalEnv = {
  NODE_ENV: process.env.NODE_ENV,
  TWILIO_AUTH_TOKEN: process.env.TWILIO_AUTH_TOKEN,
  API_BASE_URL: process.env.API_BASE_URL,
  ALLOW_UNSIGNED_TWILIO_CALLBACKS: process.env.ALLOW_UNSIGNED_TWILIO_CALLBACKS,
}

beforeAll(async () => {
  ;({ app } = await import('../../index.js'))
})

beforeEach(() => {
  vi.clearAllMocks()
  process.env.NODE_ENV = 'test'
  process.env.TWILIO_AUTH_TOKEN = originalEnv.TWILIO_AUTH_TOKEN
  process.env.API_BASE_URL = originalEnv.API_BASE_URL
  process.env.ALLOW_UNSIGNED_TWILIO_CALLBACKS = 'true'
  prismaMock.$queryRaw.mockResolvedValue([{ ok: 1 }])
  prismaMock.twilioCallback.create.mockResolvedValue({ id: 'callback-1' })
})

afterEach(() => {
  process.env.NODE_ENV = originalEnv.NODE_ENV
  process.env.TWILIO_AUTH_TOKEN = originalEnv.TWILIO_AUTH_TOKEN
  process.env.API_BASE_URL = originalEnv.API_BASE_URL
  process.env.ALLOW_UNSIGNED_TWILIO_CALLBACKS = originalEnv.ALLOW_UNSIGNED_TWILIO_CALLBACKS
})

describe('Twilio callback API', () => {
  it('persists form-encoded callback payloads with searchable fields', async () => {
    const response = await request(app)
      .post('/api/twilio/callback?type=trust_hub')
      .type('form')
      .send({
        AccountSid: 'ACtest00000000000000000000000000',
        CustomerProfileSid: 'BUtest00000000000000000000000000',
        Status: 'twilio-approved',
      })

    expect(response.status).toBe(201)
    expect(response.body).toEqual({ success: true, id: 'callback-1' })
    expect(prismaMock.twilioCallback.create).toHaveBeenCalledWith({
      data: {
        callbackType: 'trust_hub',
        accountSid: 'ACtest00000000000000000000000000',
        resourceSid: 'BUtest00000000000000000000000000',
        eventType: 'twilio-approved',
        payload: {
          AccountSid: 'ACtest00000000000000000000000000',
          CustomerProfileSid: 'BUtest00000000000000000000000000',
          Status: 'twilio-approved',
          _query: { type: 'trust_hub' },
        },
      },
      select: { id: true },
    })
  })

  it('persists JSON callback payloads', async () => {
    const response = await request(app)
      .post('/api/twilio/callback')
      .send({
        AccountSid: 'ACtest00000000000000000000000000',
        BusinessProfileSid: 'BUtestbusinessprofile000000000000',
        ReviewStatus: 'in_review',
      })

    expect(response.status).toBe(201)
    expect(prismaMock.twilioCallback.create).toHaveBeenCalledWith({
      data: {
        callbackType: 'business_profile',
        accountSid: 'ACtest00000000000000000000000000',
        resourceSid: 'BUtestbusinessprofile000000000000',
        eventType: 'in_review',
        payload: {
          AccountSid: 'ACtest00000000000000000000000000',
          BusinessProfileSid: 'BUtestbusinessprofile000000000000',
          ReviewStatus: 'in_review',
        },
      },
      select: { id: true },
    })
  })

  it('rejects invalid Twilio signatures in production', async () => {
    process.env.NODE_ENV = 'production'
    process.env.TWILIO_AUTH_TOKEN = 'test-auth-token'
    process.env.API_BASE_URL = 'https://api.makeready.org'
    twilioMock.validateRequest.mockReturnValue(false)

    const response = await request(app)
      .post('/api/twilio/callback')
      .set('x-twilio-signature', 'bad-signature')
      .type('form')
      .send({ AccountSid: 'ACtest00000000000000000000000000' })

    expect(response.status).toBe(403)
    expect(response.body.success).toBe(false)
    expect(prismaMock.twilioCallback.create).not.toHaveBeenCalled()
    expect(twilioMock.validateRequest).toHaveBeenCalledWith(
      'test-auth-token',
      'bad-signature',
      'https://api.makeready.org/api/twilio/callback',
      { AccountSid: 'ACtest00000000000000000000000000' },
    )
  })

  it('accepts valid Twilio signatures in production', async () => {
    process.env.NODE_ENV = 'production'
    process.env.TWILIO_AUTH_TOKEN = 'test-auth-token'
    process.env.API_BASE_URL = 'https://api.makeready.org/'
    twilioMock.validateRequest.mockReturnValue(true)

    const response = await request(app)
      .post('/api/twilio/callback?type=app')
      .set('x-twilio-signature', 'valid-signature')
      .type('form')
      .send({
        AccountSid: 'ACtest00000000000000000000000000',
        ApplicationSid: 'APtest00000000000000000000000000',
        EventType: 'application.updated',
      })

    expect(response.status).toBe(201)
    expect(twilioMock.validateRequest).toHaveBeenCalledWith(
      'test-auth-token',
      'valid-signature',
      'https://api.makeready.org/api/twilio/callback?type=app',
      {
        AccountSid: 'ACtest00000000000000000000000000',
        ApplicationSid: 'APtest00000000000000000000000000',
        EventType: 'application.updated',
      },
    )
    expect(prismaMock.twilioCallback.create).toHaveBeenCalled()
  })

  it('validates signed JSON callbacks with the raw request body in production', async () => {
    process.env.NODE_ENV = 'production'
    process.env.TWILIO_AUTH_TOKEN = 'test-auth-token'
    process.env.API_BASE_URL = 'https://api.makeready.org'
    twilioMock.validateRequestWithBody.mockReturnValue(true)

    const payload = {
      AccountSid: 'ACtest00000000000000000000000000',
      BusinessProfileSid: 'BUtestbusinessprofile000000000000',
      ReviewStatus: 'approved',
    }

    const response = await request(app)
      .post('/api/twilio/callback?bodySHA256=test-body-sha')
      .set('x-twilio-signature', 'valid-json-signature')
      .send(payload)

    expect(response.status).toBe(201)
    expect(twilioMock.validateRequestWithBody).toHaveBeenCalledWith(
      'test-auth-token',
      'valid-json-signature',
      'https://api.makeready.org/api/twilio/callback?bodySHA256=test-body-sha',
      JSON.stringify(payload),
    )
    expect(twilioMock.validateRequest).not.toHaveBeenCalled()
    expect(prismaMock.twilioCallback.create).toHaveBeenCalled()
  })
})

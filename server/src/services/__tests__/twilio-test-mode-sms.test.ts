import { describe, expect, it, vi } from 'vitest'

const twilioFactory = vi.hoisted(() => vi.fn())
vi.mock('twilio', () => ({ default: twilioFactory }))

describe('sendSMS in Twilio test mode (D17)', () => {
  it('returns a test sid and never constructs a Twilio client', async () => {
    vi.stubEnv('NODE_ENV', 'test')
    vi.resetModules()
    const { sendSMS } = await import('../twilio.js')
    const result = await sendSMS('+15555550123', 'hello')
    expect(result.success).toBe(true)
    expect(result.messageSid).toMatch(/^test-[0-9a-f-]{36}$/)
    expect(twilioFactory).not.toHaveBeenCalled()
    vi.unstubAllEnvs()
  })

  it('still rejects a malformed number first', async () => {
    vi.stubEnv('NODE_ENV', 'test')
    vi.resetModules()
    const { sendSMS } = await import('../twilio.js')
    const result = await sendSMS('5555550123', 'hello')
    expect(result.success).toBe(false)
    vi.unstubAllEnvs()
  })
})

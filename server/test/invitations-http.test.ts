import request from 'supertest'
import { expect, it, vi } from 'vitest'
import { startInvitationHttpServer, stopInvitationHttpServer } from './helpers/invitations-http.js'

vi.mock('dotenv', () => ({ default: { config: vi.fn(() => ({})) } }))

it('owns the same IPv4 listener that Supertest addresses and closes only that listener', async () => {
  const server = await startInvitationHttpServer((_req, res) => {
    res.writeHead(404, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ success: false, error: 'Owned test response' }))
  })
  try {
    expect(server.address()).toMatchObject({ address: '127.0.0.1', family: 'IPv4' })
    const response = await request(server).patch('/owned')
    expect(response.status).toBe(404)
    expect(response.body).toEqual({ success: false, error: 'Owned test response' })
    expect(server.listening).toBe(true)
  } finally { await stopInvitationHttpServer(server) }
  expect(server.listening).toBe(false)
})

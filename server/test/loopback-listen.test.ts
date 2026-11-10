/**
 * supertest's per-request server binds 127.0.0.1, so a request always reaches the app under test — see
 * test/helpers/loopback-listen.ts. Before the fix the server bound `::` and the app saw `::ffff:127.0.0.1`, and on
 * a port another local process held on 127.0.0.1 that process answered instead (the old-activity-routes-removed
 * flake).
 */
import { describe, expect, it } from 'vitest'
import express from 'express'
import request from 'supertest'

const app = express()
app.get('/where', (req, res) => {
  res.json({ local: req.socket.localAddress })
})
app.post('/echo', express.json(), (req, res) => {
  res.status(201).json(req.body)
})

describe('supertest servers bind the loopback address', () => {
  it('the app is reached on 127.0.0.1, not the :: wildcard', async () => {
    const res = await request(app).get('/where')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ local: '127.0.0.1' })
  })

  it('the usual chains still work: send, set, expect with a callback', async () => {
    await request(app).post('/echo').set('Content-Type', 'application/json').send({ a: 1 }).expect(201, { a: 1 })
    await new Promise<void>((resolve, reject) => {
      request(app).get('/where').expect(200, (err) => (err ? reject(err) : resolve()))
    })
  })

  it('an already-listening server is used as it is', async () => {
    const server = app.listen(0, '127.0.0.1')
    await new Promise<void>((resolve) => server.once('listening', () => resolve()))
    try {
      const res = await request(server).get('/where')
      expect(res.body).toEqual({ local: '127.0.0.1' })
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()))
    }
  })
})

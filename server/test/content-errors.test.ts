import { describe, expect, it, vi } from 'vitest'
import { ContentError, sendContentError } from '../src/services/content-errors.js'

function fakeRes() {
  const res: any = { statusCode: 0, body: undefined }
  res.status = (n: number) => ((res.statusCode = n), res)
  res.json = (b: unknown) => ((res.body = b), res)
  return res
}

describe('sendContentError', () => {
  it('writes a ContentError as its contract body', () => {
    const res = fakeRes()
    sendContentError(res, new ContentError(409, 'CONFLICT', 'x'))
    expect(res.statusCode).toBe(409)
    expect(res.body).toEqual({ success: false, error: 'x', code: 'CONFLICT' })
  })

  it('answers an unexpected error 500 INTERNAL instead of rethrowing', () => {
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {})
    const res = fakeRes()
    expect(() => sendContentError(res, new Error('db down'))).not.toThrow()
    expect(res.statusCode).toBe(500)
    expect(res.body.code).toBe('INTERNAL')
    spy.mockRestore()
  })
})

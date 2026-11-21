import { beforeEach, describe, expect, it, vi } from 'vitest'
import { S3Client } from '@aws-sdk/client-s3'
import { headObject, presignClientConfig, presignGet, presignPut } from '../storage.js'

// D9/D31/D34: memo audio goes up and down through presigned R2 URLs; the object size comes from HEAD.
const env = { R2_ACCOUNT_ID: 'acct', R2_ACCESS_KEY_ID: 'key', R2_SECRET_ACCESS_KEY: 'secret', R2_ENDPOINT: 'http://localhost:9010', R2_BUCKET_NAME: 'b' }
beforeEach(() => { Object.assign(process.env, env); delete process.env.R2_PRESIGN_ENDPOINT })

describe('presign', () => {
  it('presignPut signs content-length and content-type and expires in 15 min', async () => {
    const url = new URL(await presignPut('memos/u1/m1.m4a', 'audio/mp4', 1234, 900))
    const signed = url.searchParams.get('X-Amz-SignedHeaders')!.split(';')
    expect(signed).toEqual(expect.arrayContaining(['content-length', 'content-type', 'host']))
    expect(url.searchParams.get('X-Amz-Expires')).toBe('900')
    expect(url.pathname).toBe('/b/memos/u1/m1.m4a')
    expect(new URL(await presignGet('memos/u1/m1.m4a', 3600)).searchParams.get('X-Amz-Expires')).toBe('3600')
  })

  it('R2_PRESIGN_ENDPOINT changes the signed host', async () => {
    expect(presignClientConfig({ ...env, R2_PRESIGN_ENDPOINT: 'http://192.168.1.5:9090' })).toMatchObject({ endpoint: 'http://192.168.1.5:9090', forcePathStyle: true })
    expect(presignClientConfig({ ...env, R2_PRESIGN_ENDPOINT: '' }).endpoint).toBe('http://localhost:9010')
  })
})

describe('headObject', () => {
  it('headObject returns the size, and null when absent', async () => {
    const send = vi.spyOn(S3Client.prototype, 'send')
    send.mockResolvedValueOnce({ ContentLength: 42 } as never)
    expect(await headObject('k')).toEqual({ contentLength: 42 })
    send.mockRejectedValueOnce(Object.assign(new Error('nf'), { name: 'NotFound', $metadata: { httpStatusCode: 404 } }))
    expect(await headObject('k')).toBeNull()
    send.mockRejectedValueOnce(Object.assign(new Error('boom'), { $metadata: { httpStatusCode: 500 } }))
    await expect(headObject('k')).rejects.toThrow('boom')
  })
})

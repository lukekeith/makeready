import { describe, expect, it } from 'vitest'
import { r2ClientConfig } from '../storage.js'

// walk-image-storage: R2_ENDPOINT points the S3 client at a local S3-compatible store (MinIO on the
// agent walk); unset, the client talks to Cloudflare R2 exactly as before.
const creds = { R2_ACCOUNT_ID: 'acct', R2_ACCESS_KEY_ID: 'key', R2_SECRET_ACCESS_KEY: 'secret' }

describe('r2ClientConfig', () => {
  it('uses the Cloudflare R2 endpoint, virtual-hosted, when R2_ENDPOINT is unset', () => {
    const config = r2ClientConfig(creds)
    expect(config.endpoint).toBe('https://acct.r2.cloudflarestorage.com')
    expect(config.forcePathStyle).toBeUndefined()
    expect(config.region).toBe('auto')
    expect(config.credentials).toEqual({ accessKeyId: 'key', secretAccessKey: 'secret' })
  })

  it('uses R2_ENDPOINT with path-style addressing when set', () => {
    const config = r2ClientConfig({ ...creds, R2_ENDPOINT: 'http://localhost:9010' })
    expect(config.endpoint).toBe('http://localhost:9010')
    expect(config.forcePathStyle).toBe(true)
  })

  it('treats an empty R2_ENDPOINT as unset', () => {
    expect(r2ClientConfig({ ...creds, R2_ENDPOINT: '' }).endpoint).toBe('https://acct.r2.cloudflarestorage.com')
  })

  it('throws without credentials, as before', () => {
    expect(() => r2ClientConfig({ R2_ENDPOINT: 'http://localhost:9010' })).toThrow(/R2 credentials not configured/)
  })
})

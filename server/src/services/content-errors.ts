/**
 * text-activity D35: errors on the new content routes are `{ success: false, error, code }`.
 * Services throw `ContentError`; routes hand any thrown error to `sendContentError`.
 */
import type { Response } from 'express'

export type ContentErrorCode = 'VALIDATION' | 'NOT_FOUND' | 'NOT_DRAFT' | 'CONFLICT' | 'TOO_LARGE' | 'IN_USE'

export class ContentError extends Error {
  constructor(
    readonly status: number,
    readonly code: ContentErrorCode,
    message: string,
  ) {
    super(message)
    this.name = 'ContentError'
  }
}

/** Writes a `ContentError` as the contract's error body; rethrows anything else. */
export function sendContentError(res: Response, err: unknown): Response {
  if (err instanceof ContentError) {
    return res.status(err.status).json({ success: false, error: err.message, code: err.code })
  }
  throw err
}

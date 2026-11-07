/**
 * text-activity D35: errors on the new content routes are `{ success: false, error, code }`.
 * Services throw `ContentError`; routes hand any thrown error to `sendContentError`.
 */
import type { Response } from 'express'
import type { z } from 'zod'

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

/** Parses a request body; a failure is a 400 `VALIDATION` naming the first issue. */
export function parseContentBody<S extends z.ZodTypeAny>(schema: S, body: unknown): z.infer<S> {
  const parsed = schema.safeParse(body)
  if (!parsed.success) {
    const issue = parsed.error.issues[0]
    throw new ContentError(400, 'VALIDATION', [issue.path.join('.'), issue.message].filter(Boolean).join(': '))
  }
  return parsed.data
}

/**
 * group-cover-image: the non-destructive group cover — the framing shape (D11). Task 3 adds the
 * upload service (D10, D17) to this module.
 */
import { z } from 'zod'

/** D11: all finite; scale relative to the zoom floor (1…8), degrees, fractions of the frame. */
export const coverFramingSchema = z
  .object({
    scale: z.number().finite().min(1).max(8),
    rotation: z.number().finite().min(-180).max(180),
    offsetX: z.number().finite().min(-1).max(1),
    offsetY: z.number().finite().min(-1).max(1),
  })
  .strict()

export type CoverFraming = z.infer<typeof coverFramingSchema>

/** A stored `coverFraming` as the payload returns it — null when absent or not D11-shaped. */
export function parseStoredFraming(value: unknown): CoverFraming | null {
  const parsed = coverFramingSchema.safeParse(value)
  return parsed.success ? parsed.data : null
}

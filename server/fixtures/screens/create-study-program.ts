/**
 * create-study-program layer (ui2-programs D8, D17): the form starts empty and writes through
 * POST /api/programs — no fixture rows. A program a walk creates belongs to the fixture org, so the
 * next reset deletes it (wipe.ts step 3).
 */
import type { FixtureContext } from '../context.js'

export async function full(_ctx: FixtureContext): Promise<void> {}

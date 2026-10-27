/**
 * create-group layer (ui2-groups-browse D8, D19): the form starts empty and writes through
 * POST /api/groups — no fixture rows. The group a walk creates belongs to the fixture org, so the
 * next reset deletes it (wipe.ts step 3).
 */
import type { FixtureContext } from '../context.js'

export async function full(_ctx: FixtureContext): Promise<void> {}

/**
 * groups-home layer (ui2-groups-browse D3, D19): the Groups list reads only base — five groups in
 * one org (Tuesday Men's Group, Young Adults, Women's Bible Study and Empty Group by Fixture Leader;
 * Prayer Team by Nathan Hughes), so the Leaders chip offers two names and the Orgs chip stays hidden
 * (one org, D3). Covers come from base's images. Nothing to add; the layer exists so the screen is
 * registered in `screens/` (README §A new screen layer).
 */
import type { FixtureContext } from '../context.js'

export async function full(_ctx: FixtureContext): Promise<void> {}

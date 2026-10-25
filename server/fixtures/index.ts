/**
 * Process entry for `npm run fixtures:reset [-- <scenario>]` and
 * `npm run fixtures:seed [-- <scenario>]` (SPEC ui2-fixtures D4).
 * Ends with process.exit: the analytics service's pg pool has no exported
 * close, so the process would otherwise never exit (D10).
 */
import { liveDeps, main } from './runner.js'

main(process.argv.slice(2), process.env, liveDeps()).then(
  (code) => process.exit(code),
  (err: unknown) => {
    console.error('fixtures: unexpected failure —', err)
    process.exit(1)
  }
)

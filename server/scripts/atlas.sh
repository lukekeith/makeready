#!/usr/bin/env bash
# Runs Atlas: the repo-local server/bin/atlas when installed (it is gitignored, so fresh
# clones and worktrees lack it), otherwise the `atlas` on PATH.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -x "$here/bin/atlas" ]; then exec "$here/bin/atlas" "$@"; fi
if command -v atlas >/dev/null 2>&1; then exec atlas "$@"; fi
echo "atlas not found: install it to server/bin/atlas or on PATH (https://atlasgo.io/getting-started#installation)" >&2
exit 127

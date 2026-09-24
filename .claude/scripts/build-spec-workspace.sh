#!/usr/bin/env bash
# build-spec-workspace.sh <feature> — the SDD workspace for ONE feature.
#
# superpowers' `sdd-workspace PLAN_FILE` names the workspace after the plan file's basename, so
# every feature's PLAN.md would collide on ".superpowers/sdd/PLAN/". This prints
# <repo>/.superpowers/sdd/<feature>/ instead and is what builder:build passes as the explicit
# OUTFILE to SDD's `task-brief` and `review-package` (both accept one). The superpowers scripts
# are not forked. Same location + self-ignoring .gitignore as SDD's own, so `git status` never
# sees a brief, report, ledger or review diff.
set -euo pipefail

usage() { echo "usage: build-spec-workspace.sh <feature> | --self-test" >&2; exit 2; }
[ $# -eq 1 ] || usage

root=$(git rev-parse --show-toplevel)
base="$root/.superpowers/sdd"

workspace() {
  local feature=$1
  case "$feature" in ''|.|..|*/*|*' '*) echo "feature must be a bare folder name (got: '$feature')" >&2; exit 2;; esac
  mkdir -p "$base/$feature"
  printf '*\n' > "$base/.gitignore"
  printf '%s\n' "$base/$feature"
}

if [ "$1" = "--self-test" ]; then
  a=$(workspace "__selftest_a"); b=$(workspace "__selftest_b")
  [ "$a" != "$b" ] || { echo "FAIL: two features share a directory" >&2; exit 1; }
  [ -d "$a" ] && [ -d "$b" ] || { echo "FAIL: directory not created" >&2; exit 1; }
  git -C "$root" check-ignore -q "$a" || { echo "FAIL: workspace is not git-ignored" >&2; exit 1; }
  ( workspace "a/b" >/dev/null 2>&1 ) && { echo "FAIL: a slash in the name was accepted" >&2; exit 1; }
  rm -rf "$a" "$b"
  echo "ok: build-spec-workspace self-test"
  exit 0
fi

workspace "$1"

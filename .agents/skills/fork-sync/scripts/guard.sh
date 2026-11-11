#!/usr/bin/env bash
# Make pushing to upstream impossible from this clone. Idempotent; sync.sh runs it first.
set -euo pipefail

UPSTREAM_SLUG=pingdotgg/t3code
UPSTREAM_URL=git@github.com:$UPSTREAM_SLUG.git
HOOK_MARKER=fork-sync-pre-push-guard

die() { echo "fork-guard: $*" >&2; exit 1; }

cd "$(git rev-parse --show-toplevel)"

origin_url=$(git remote get-url origin 2>/dev/null) || die "no 'origin' remote; it must be your fork"
case "$origin_url" in
  *"$UPSTREAM_SLUG"*) die "origin ($origin_url) is upstream; point it at your fork" ;;
esac

if git remote get-url upstream >/dev/null 2>&1; then
  git remote set-url upstream "$UPSTREAM_URL"
else
  git remote add upstream "$UPSTREAM_URL"
fi
git remote set-url --push upstream DISABLED_never_push_to_upstream
git config remote.pushDefault origin

# Without this, `gh pr create` in a fork targets the parent repo.
fork_slug=$(sed -E 's#^(git@github\.com:|ssh://git@github\.com/|https://github\.com/)##; s#\.git$##' <<<"$origin_url")
gh repo set-default "$fork_slug" >/dev/null

# .vite-hooks/pre-push must run on every push. `vp i` points core.hooksPath at vp's dispatcher,
# which runs it; before that, git reads .git/hooks.
[ -x .vite-hooks/pre-push ] || die ".vite-hooks/pre-push is missing or not executable"
hooks_path=$(git config --get core.hooksPath || true)
case "$hooks_path" in
  .vite-hooks/_) ;;
  "")
    hook=$(git rev-parse --git-path hooks)/pre-push
    if [ -e "$hook" ] && ! grep -q "$HOOK_MARKER" "$hook"; then
      die "$hook exists and is not ours; make it also run .vite-hooks/pre-push"
    fi
    mkdir -p "$(dirname "$hook")"
    printf '#!/bin/sh\n# %s\nexec "$(git rev-parse --show-toplevel)/.vite-hooks/pre-push" "$@"\n' "$HOOK_MARKER" >"$hook"
    chmod +x "$hook"
    ;;
  *) die "core.hooksPath is '$hooks_path', so .vite-hooks/pre-push never runs; wire it in by hand" ;;
esac

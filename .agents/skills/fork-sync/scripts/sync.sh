#!/usr/bin/env bash
# Rebase the fork's own commits onto upstream's default branch, then push to origin (the fork).
set -euo pipefail

die() { echo "fork-sync: $*" >&2; exit 1; }

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$(git rev-parse --show-toplevel)"
"$here/guard.sh"

git rev-parse -q --verify REBASE_HEAD >/dev/null &&
  die "a rebase is in progress: finish it with 'git rebase --continue' or drop it with 'git rebase --abort', then rerun"
[ -z "$(git status --porcelain --untracked-files=no)" ] ||
  die "uncommitted changes; commit or stash them first"

branch=$(git ls-remote --symref upstream HEAD | sed -n 's#^ref: refs/heads/\(.*\)\tHEAD$#\1#p')
[ -n "$branch" ] || die "could not resolve upstream's default branch"

# Upstream has thousands of branches; track only its default one.
git config --replace-all remote.upstream.fetch "+refs/heads/$branch:refs/remotes/upstream/$branch"
git fetch --quiet --prune upstream
git fetch --quiet --prune origin

git show-ref -q --verify "refs/heads/$branch" ||
  die "upstream's default branch is now '$branch' and this clone has no local '$branch'. Rename yours (git branch -m <old> $branch), push it to origin, make it the fork's default on GitHub, then rerun"
git switch --quiet "$branch"

if git show-ref -q --verify "refs/remotes/origin/$branch"; then
  # Commits pushed to the fork from another clone: take them first.
  if git merge-base --is-ancestor HEAD "origin/$branch"; then
    git merge --quiet --ff-only "origin/$branch"
  fi
  # A '+' line is a fork commit with no equivalent patch here; force-pushing would drop it.
  if git cherry HEAD "origin/$branch" | grep -q '^+'; then
    die "origin/$branch has commits missing locally. Inspect: git log --oneline --cherry-pick --right-only $branch...origin/$branch"
  fi
fi

old_upstream=$(git merge-base HEAD "upstream/$branch")
git rebase --quiet "upstream/$branch" ||
  die "rebase stopped on a conflict. Resolve it, run 'git rebase --continue', then rerun this script to push. 'git rebase --abort' restores $branch"

git push --quiet --force-with-lease --force-if-includes origin "$branch"

echo "fork-sync: pulled $(git rev-list --count "$old_upstream..upstream/$branch") upstream commit(s) from upstream/$branch"
echo "fork-sync: origin/$branch = upstream/$branch + $(git rev-list --count "upstream/$branch..$branch") fork commit(s):"
git log --oneline "upstream/$branch..$branch"

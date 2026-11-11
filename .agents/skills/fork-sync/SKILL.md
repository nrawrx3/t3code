---
name: fork-sync
description: Keep this clone's fork (origin) on top of upstream pingdotgg/t3code's default branch, and rebuild the local dnf package from it. Use for "sync the fork", "pull upstream", "update from upstream", "rebuild/reinstall t3code", or before pushing anything. Never pushes to upstream.
---

# Fork sync

`origin` is the fork. `upstream` is pingdotgg/t3code. The fork's default branch is
upstream's default branch plus a short stack of fork-only commits on top.

## Rules

- Never push to `upstream`. Push only to `origin`. Do not open PRs, issues, or comments
  on pingdotgg/t3code.
- Never undo the guards in `scripts/guard.sh`: the disabled upstream push URL, the
  `pre-push` hook, `remote.pushDefault=origin`, and `gh repo set-default` on the fork.
  If a command fails because of a guard, the command is wrong.
- Rewrite history only on the fork's default branch, and only through `scripts/sync.sh`.

## Sync

```sh
.agents/skills/fork-sync/scripts/sync.sh
```

The script runs `guard.sh` first. Then it finds upstream's default branch with
`git ls-remote --symref upstream HEAD`, so a `master`/`main` rename is caught. It rebases the
fork commits onto that branch and runs `git push --force-with-lease origin <branch>`. It stops
on a dirty tree, an unfinished rebase, or a fork commit that exists only on origin. Each of
those stops prints the next command to run.

On a conflict, the script stops in the middle of the rebase. Resolve the files, run
`git rebase --continue`, then run `sync.sh` again to push. Fork commits only add files
under `packaging/rpm/` and `.agents/skills/fork-sync/`, so a conflict means upstream started
using one of those paths.

Feature branches are left alone. Rebase them yourself afterwards with `git rebase <branch>`.

## Rebuild the installed app

```sh
packaging/rpm/build.sh                         # build HEAD into ~/werk/t3code-rpms
sudo dnf upgrade --refresh t3code              # the user runs this; it needs a password
```

`build.sh` does nothing if HEAD is already published (`--force` rebuilds it). The RPM's
release field is HEAD's commit time plus its hash, so every synced commit sorts as an upgrade.
The script keeps the three newest builds so that `sudo dnf downgrade t3code` works. No update
feed is baked into the build, so the in-app updater stays off and dnf owns upgrades.

A build takes several minutes. Run it in the background. Check the result in the last lines of
its output.

## First-time setup on a new machine

1. Clone the fork, then run `scripts/guard.sh`.
2. Install `vp` (see the root README), Rust 1.95 or newer, and the Linux prerequisites in
   `docs/operations/development.md#linux-appimage-prerequisites`. Then run
   `sudo dnf install createrepo_c`.
3. Run `packaging/rpm/build.sh`, then
   `sudo install -m644 ~/werk/t3code-rpms/t3code-local.repo /etc/yum.repos.d/` and
   `sudo dnf install t3code`.

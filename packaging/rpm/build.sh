#!/usr/bin/env bash
# Build T3 Code desktop from HEAD as an RPM and publish it to a local dnf repo.
#   packaging/rpm/build.sh          skip if HEAD is already published
#   packaging/rpm/build.sh --force  rebuild anyway
# Repo location: $T3CODE_RPM_REPO, default ~/werk/t3code-rpms.
set -euo pipefail

die() { echo "rpm-build: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "'$1' not found. $2"; }

root=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
cd "$root"
repo_dir=${T3CODE_RPM_REPO:-$HOME/werk/t3code-rpms}
force=0
[ "${1:-}" = --force ] && force=1

need vp "Install it: curl -fsSL https://vite.plus | bash"
need rpmbuild "Install it: sudo dnf install rpm-build"
need createrepo_c "Install it: sudo dnf install createrepo_c"
need magick "Install it: sudo dnf install ImageMagick"
need jq "Install it: sudo dnf install jq"

[ -z "$(git status --porcelain --untracked-files=no)" ] ||
  die "commit your changes first; the package release is derived from HEAD"

# RPM versions cannot contain '-'; '~' keeps prereleases sorting below the release.
version=$(jq -r .version apps/desktop/package.json | tr - '~')
commit=$(git rev-parse HEAD)
# Committer time rises with every rebase, so each new build sorts as an upgrade.
release="$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y%m%d%H%M%S).git${commit:0:10}"
nvr="t3code-$version-$release$(rpm --eval '%{?dist}')"

if [ "$force" = 0 ] && compgen -G "$repo_dir/$nvr.*.rpm" >/dev/null; then
  echo "rpm-build: $nvr is already in $repo_dir (--force rebuilds it)"
  exit 0
fi

# Under release/ (gitignored) rather than /tmp: the unpacked app is too big for a tmpfs.
work=$root/release/rpm
rm -rf "$work"
mkdir -p "$work"

# Electron builds outgrow a tmpfs /tmp. Keep TMPDIR outside the repo: the bundle self-check
# fails when a node_modules is visible from it.
export TMPDIR=${XDG_CACHE_HOME:-$HOME/.cache}/t3code-rpm-tmp
rm -rf "$TMPDIR"
mkdir -p "$TMPDIR"

# No update feed gets baked in, so the app's self-updater stays off and dnf owns upgrades.
unset GITHUB_REPOSITORY T3CODE_DESKTOP_UPDATE_REPOSITORY T3CODE_DESKTOP_VERSION
vp i
vp run dist:desktop:artifact --platform linux --target dir --arch x64 --output-dir "$work/app"
[ -x "$work/app/linux-unpacked/t3code" ] || die "build produced no $work/app/linux-unpacked/t3code"

for size in 16 22 24 32 48 64 128 256 512; do
  mkdir -p "$work/icons/${size}x${size}/apps"
  magick assets/prod/black-universal-1024.png -resize "${size}x${size}" "$work/icons/${size}x${size}/apps/t3code.png"
done

rpmbuild -bb packaging/rpm/t3code.spec \
  --define "_topdir $work/rpmbuild" \
  --define "_binary_payload w3.zstdio" \
  --define "t3_version $version" \
  --define "t3_release $release" \
  --define "t3_commit $commit" \
  --define "t3_url $(git remote get-url origin | sed -E 's#^git@github\.com:#https://github.com/#; s#\.git$##')" \
  --define "t3_app $work/app/linux-unpacked" \
  --define "t3_icons $work/icons" \
  --define "t3_root $root"

mkdir -p "$repo_dir"
cp "$work"/rpmbuild/RPMS/x86_64/"$nvr".x86_64.rpm "$repo_dir/"
# Keep the three newest builds so `dnf downgrade t3code` has somewhere to go.
ls -t "$repo_dir"/t3code-*.rpm | tail -n +4 | xargs -r rm --
createrepo_c --quiet --update "$repo_dir"

cat >"$repo_dir/t3code-local.repo" <<EOF
[t3code-local]
name=T3 Code (local builds of $(basename "$root"))
baseurl=file://$repo_dir
enabled=1
gpgcheck=0
metadata_expire=0
skip_if_unavailable=True
EOF

rm -rf "$work" "$TMPDIR"
echo "rpm-build: published $nvr to $repo_dir"
if [ -f /etc/yum.repos.d/t3code-local.repo ]; then
  echo "rpm-build: install or upgrade with: sudo dnf upgrade --refresh t3code   (first time: sudo dnf install t3code)"
else
  echo "rpm-build: register the repo once: sudo install -m644 $repo_dir/t3code-local.repo /etc/yum.repos.d/"
fi

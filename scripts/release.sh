#!/usr/bin/env bash
# For maintainers: publish what's on main as a release.
#
#   bash scripts/release.sh 0.2.0
#
# Auto-update on everyone's server follows the `stable` branch, so nothing
# reaches them until you run this. Before releasing, try main on your own
# server (bash scripts/update.sh) and add a "## 0.2.0" section to CHANGELOG.md.
#
# It checks you're on an up-to-date, clean main with passing checks and a
# changelog entry, then tags v0.2.0 and moves `stable` to it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
V="${1:-}"
die() { printf 'xx %s\n' "$*" >&2; exit 1; }
[[ "$V" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Usage: release.sh X.Y.Z"
[[ "$(git rev-parse --abbrev-ref HEAD)" == main ]] || die "Switch to main first."
[[ -z "$(git status --porcelain)" ]] || die "Commit or stash your changes first."
git fetch -q origin
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "Local main differs from GitHub; pull or push first."
git rev-parse -q --verify "refs/tags/v$V" >/dev/null && die "v$V already exists."
grep -q "^## $V" CHANGELOG.md || die "Add a '## $V' section to CHANGELOG.md (and push it) first."
bash tests/lint.sh >/dev/null || die "Checks fail: run bash tests/lint.sh"
if git rev-parse -q --verify origin/stable >/dev/null; then
  git merge-base --is-ancestor origin/stable HEAD || die "stable has commits main doesn't; fix that by hand."
fi
echo "Releasing v$V ($(git log --oneline -1)), tested with Hermes $(cat HERMES_VERSION)."
read -r -p "Have you run this on your own server? [y/N] " a </dev/tty
[[ "$a" =~ ^[Yy] ]] || die "Try it first: bash scripts/update.sh on your server."
git tag -a "v$V" -m "Sidekick $V"
git push origin "v$V"
git push origin "HEAD:refs/heads/stable"
echo "Done. Servers on auto-update pick up v$V tonight."

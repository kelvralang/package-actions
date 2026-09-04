#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^v2\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: release-v2.sh v2.MINOR.PATCH" >&2
    exit 2
fi

VERSION="$1"
REPOSITORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPOSITORY"

command -v gh >/dev/null || { echo "gh is required" >&2; exit 1; }
[[ "$(git branch --show-current)" == main ]] || { echo "release from main" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "working tree must be clean" >&2; exit 1; }
git fetch origin main --tags
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || {
    echo "local main must exactly match origin/main" >&2
    exit 1
}
if git rev-parse --verify --quiet "refs/tags/$VERSION" >/dev/null; then
    echo "immutable tag already exists: $VERSION" >&2
    exit 1
fi

HEAD_SHA="$(git rev-parse HEAD)"
SUCCESS_SHA="$(gh run list --workflow fixtures.yml --branch main --status success \
    --limit 20 --json headSha --jq '.[].headSha' | grep -Fx "$HEAD_SHA" | head -n 1 || true)"
[[ "$SUCCESS_SHA" == "$HEAD_SHA" ]] || {
    echo "fixtures.yml has no successful main run for $HEAD_SHA" >&2
    exit 1
}

git tag -a "$VERSION" -m "Kelvra package actions $VERSION"
git push origin "$VERSION"
gh release create "$VERSION" --verify-tag --generate-notes \
    --title "Kelvra package actions $VERSION"

git tag -f -a v2 -m "Kelvra package actions v2" "$HEAD_SHA"
git push --force origin refs/tags/v2

echo "Published immutable $VERSION and advanced v2 to $HEAD_SHA"

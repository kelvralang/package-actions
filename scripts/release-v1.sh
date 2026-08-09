#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^v1\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: release-v1.sh v1.MINOR.PATCH" >&2
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

git tag -a "$VERSION" -m "Mog package actions $VERSION"
git push origin "$VERSION"
gh release create "$VERSION" --verify-tag --generate-notes \
    --title "Mog package actions $VERSION"

git tag -f -a v1 -m "Mog package actions v1" "$HEAD_SHA"
git push --force origin refs/tags/v1

echo "Published immutable $VERSION and advanced v1 to $HEAD_SHA"

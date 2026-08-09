#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOG_SOURCE="${MOG_SOURCE:-$REPOSITORY/../mog}"
BUILD_DIR="${BUILD_DIR:-$MOG_SOURCE/build}"
MOG_RUNTIME="${MOG_RUNTIME:-$BUILD_DIR/interpreter}"

for script in "$REPOSITORY"/scripts/*.sh "$REPOSITORY"/fixtures/native/tests/*.sh; do
    bash -n "$script"
done

if command -v actionlint >/dev/null 2>&1; then
    actionlint "$REPOSITORY"/.github/workflows/*.yml
fi

if [[ ! -x "$MOG_RUNTIME" ]]; then
    cmake -S "$MOG_SOURCE" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$BUILD_DIR" --parallel
fi

SOURCE="$REPOSITORY/fixtures/source"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SOURCE_STAGE="$WORK/packages/github.com/moglang/package-actions-source-fixture"
SOURCE_PROJECT="$WORK/source-project"
mkdir -p "$SOURCE_STAGE" "$SOURCE_PROJECT"
cp -R "$SOURCE/." "$SOURCE_STAGE/"
"$MOG_RUNTIME" validate-package "$SOURCE_STAGE"
sed -e 's|__PACKAGE_NAME__|package-actions-source-fixture|g' \
    -e 's|__PACKAGE_MODULE__|github.com/moglang/package-actions-source-fixture|g' \
    -e 's|__PACKAGE_VERSION__|0.1.0|g' \
    -e "s|__PACKAGE_PATH__|$SOURCE_STAGE|g" \
    "$SOURCE/package-test.toml.in" > "$SOURCE_PROJECT/mog.toml"
(
    cd "$SOURCE_PROJECT"
    MOG_CACHE_DIR="$WORK/source-cache" "$MOG_RUNTIME" run "$SOURCE_STAGE/tests/main.mog"
)

"$REPOSITORY/fixtures/native/tests/test_native_package.sh" \
    "$MOG_RUNTIME" "$REPOSITORY/fixtures/native"

echo "package-actions contract fixtures passed"

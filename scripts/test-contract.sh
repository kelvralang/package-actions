#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KELVRA_SOURCE="${KELVRA_SOURCE:-$REPOSITORY/../mog}"
BUILD_DIR="${BUILD_DIR:-$KELVRA_SOURCE/build}"
KELVRA_RUNTIME="${KELVRA_RUNTIME:-$BUILD_DIR/kelvra}"

for script in "$REPOSITORY"/scripts/*.sh "$REPOSITORY"/fixtures/native/tests/*.sh; do
    bash -n "$script"
done

if command -v actionlint >/dev/null 2>&1; then
    actionlint "$REPOSITORY"/.github/workflows/*.yml
fi

if [[ ! -x "$KELVRA_RUNTIME" ]]; then
    cmake -S "$KELVRA_SOURCE" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
    cmake --build "$BUILD_DIR" --parallel
fi

SOURCE="$REPOSITORY/fixtures/source"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SOURCE_STAGE="$WORK/packages/github.com/kelvralang/package-actions-source-fixture"
SOURCE_PROJECT="$WORK/source-project"
mkdir -p "$SOURCE_STAGE" "$SOURCE_PROJECT"
cp -R "$SOURCE/." "$SOURCE_STAGE/"
"$KELVRA_RUNTIME" validate-package "$SOURCE_STAGE"
sed -e 's|__PACKAGE_NAME__|package-actions-source-fixture|g' \
    -e 's|__PACKAGE_MODULE__|github.com/kelvralang/package-actions-source-fixture|g' \
    -e 's|__PACKAGE_VERSION__|0.2.0|g' \
    -e "s|__PACKAGE_PATH__|$SOURCE_STAGE|g" \
    "$SOURCE/package-test.toml.in" > "$SOURCE_PROJECT/kelvra.toml"
(
    cd "$SOURCE_PROJECT"
    KELVRA_CACHE_DIR="$WORK/source-cache" "$KELVRA_RUNTIME" run "$SOURCE_STAGE/tests/main.kel"
)

"$REPOSITORY/fixtures/native/tests/test_native_package.sh" \
    "$KELVRA_RUNTIME" "$REPOSITORY/fixtures/native"

echo "package-actions contract fixtures passed"

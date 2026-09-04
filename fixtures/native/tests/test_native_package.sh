#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: test_native_package.sh /path/to/kelvra /path/to/package" >&2
    exit 2
fi

KELVRA="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
PACKAGE="$(cd "$2" && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

cmake -S "$PACKAGE" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --parallel

STAGE="$BUILD_DIR/stage/github.com/kelvralang/package-actions-native-fixture"
mkdir -p "$STAGE"
cp -R "$PACKAGE/." "$STAGE/"
if [[ "$(uname -s)" == Darwin ]]; then
    LIBRARY_NAME="package.dylib"
else
    LIBRARY_NAME="package.so"
fi
cp "$BUILD_DIR/package.so" "$STAGE/$LIBRARY_NAME"
"$KELVRA" validate-package "$STAGE"

PROJECT="$BUILD_DIR/project"
mkdir -p "$PROJECT"
sed -e "s|__PACKAGE_PATH__|$STAGE|g" "$PACKAGE/tests/project.kel.toml.in" > "$PROJECT/kelvra.toml"
(
    cd "$PROJECT"
    KELVRA_CACHE_DIR="$BUILD_DIR/cache" "$KELVRA" run "$STAGE/tests/main.kel"
)

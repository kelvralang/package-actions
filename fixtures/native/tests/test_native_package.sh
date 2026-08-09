#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: test_native_package.sh /path/to/mog /path/to/package" >&2
    exit 2
fi

MOG="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
PACKAGE="$(cd "$2" && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

cmake -S "$PACKAGE" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --parallel

STAGE="$BUILD_DIR/stage/github.com/moglang/package-actions-native-fixture"
mkdir -p "$STAGE"
cp -R "$PACKAGE/." "$STAGE/"
if [[ "$(uname -s)" == Darwin ]]; then
    LIBRARY_NAME="package.dylib"
else
    LIBRARY_NAME="package.so"
fi
cp "$BUILD_DIR/package.so" "$STAGE/$LIBRARY_NAME"
"$MOG" validate-package "$STAGE"

PROJECT="$BUILD_DIR/project"
mkdir -p "$PROJECT"
sed -e "s|__PACKAGE_PATH__|$STAGE|g" "$PACKAGE/tests/project.mog.toml.in" > "$PROJECT/mog.toml"
(
    cd "$PROJECT"
    MOG_CACHE_DIR="$BUILD_DIR/cache" "$MOG" run "$STAGE/tests/main.mog"
)

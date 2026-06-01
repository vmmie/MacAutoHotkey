#!/bin/sh
set -eu

VERSION="${1:-0.3.0}"
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PACKAGE_NAME="MacAutoHotkey-$VERSION"
PACKAGE_DIR="$ROOT_DIR/dist/$PACKAGE_NAME"
ZIP_PATH="$ROOT_DIR/dist/$PACKAGE_NAME-macos-arm64.zip"

cd "$ROOT_DIR"
"$ROOT_DIR/Scripts/build_app.sh"

rm -rf "$PACKAGE_DIR" "$ZIP_PATH"
mkdir -p "$PACKAGE_DIR"

cp -R "$ROOT_DIR/dist/MacAutoHotkey.app" "$PACKAGE_DIR/"
cp -R "$ROOT_DIR/Examples" "$PACKAGE_DIR/"
cp "$ROOT_DIR/README.md" "$PACKAGE_DIR/"

cd "$ROOT_DIR/dist"
zip -r "$ZIP_PATH" "$PACKAGE_NAME" -x "*.DS_Store"

echo "Packaged $ZIP_PATH"

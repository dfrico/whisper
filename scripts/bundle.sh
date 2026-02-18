#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Whisper"
BUNDLE_DIR="$PROJECT_DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LIB_DIR="$PROJECT_DIR/vendor/lib"

# Build whisper.cpp static libs if not present
"$SCRIPT_DIR/build-whisper.sh"

# Build release
echo "Building $APP_NAME..."
cd "$PROJECT_DIR"
swift build -c release

# Locate the built binary
BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    exit 1
fi

# Clean previous bundle
rm -rf "$BUNDLE_DIR"

# Create bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BINARY" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy Metal shader library if present
METALLIB="$LIB_DIR/ggml-metal.metallib"
if [ -f "$METALLIB" ]; then
    cp "$METALLIB" "$RESOURCES_DIR/"
    echo "Copied Metal shader library to Resources"
else
    # Try alternative names
    for f in "$LIB_DIR"/*.metallib; do
        if [ -f "$f" ]; then
            cp "$f" "$RESOURCES_DIR/"
            echo "Copied $(basename "$f") to Resources"
        fi
    done
fi

echo "Created $BUNDLE_DIR"

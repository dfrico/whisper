#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WHISPER_SRC="$PROJECT_DIR/vendor/whisper.cpp"

# Ensure cmake is on PATH (asdf shims)
export PATH="$HOME/.asdf/shims:$PATH"
BUILD_DIR="$WHISPER_SRC/build-apple"
LIB_DIR="$PROJECT_DIR/vendor/lib"

if [ ! -d "$WHISPER_SRC" ]; then
    echo "Error: whisper.cpp source not found at $WHISPER_SRC"
    echo "Run: git submodule update --init"
    exit 1
fi

# Skip rebuild if libs already exist (pass --force to rebuild)
if [ "${1:-}" != "--force" ] && [ -f "$LIB_DIR/libwhisper.a" ] && [ -f "$LIB_DIR/libggml.a" ]; then
    echo "whisper.cpp static libs already built in $LIB_DIR (use --force to rebuild)"
    exit 0
fi

echo "Building whisper.cpp static libraries..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cmake -S "$WHISPER_SRC" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_METAL=ON \
    -DGGML_ACCELERATE=ON \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DCMAKE_OSX_ARCHITECTURES="$(uname -m)"

cmake --build "$BUILD_DIR" --config Release -j "$(sysctl -n hw.logicalcpu)"

# Collect static libs
mkdir -p "$LIB_DIR"

find "$BUILD_DIR" -name "*.a" -exec cp {} "$LIB_DIR/" \;

# Copy Metal shader lib if present
METALLIB=$(find "$BUILD_DIR" -name "*.metallib" -print -quit 2>/dev/null || true)
if [ -n "$METALLIB" ]; then
    cp "$METALLIB" "$LIB_DIR/"
    echo "Copied Metal shader library"
fi

echo ""
echo "Static libraries collected in $LIB_DIR:"
ls -la "$LIB_DIR/"
echo ""
echo "Build complete."

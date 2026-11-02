#!/bin/sh
set -eu

SCRIPTS_DIRECTORY=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIRECTORY=$(dirname -- "$SCRIPTS_DIRECTORY")
RUST_DIRECTORY="$PROJECT_DIRECTORY/rust"
NATIVE_DIRECTORY="$PROJECT_DIRECTORY/app/macos/native"
BRIDGE_CRATE=orchestration-ffi
LIBRARY_FILE_NAME=liborchestration_ffi.dylib
APPLE_SILICON_TARGET=aarch64-apple-darwin
INTEL_TARGET=x86_64-apple-darwin
INSTALL_NAME="@rpath/$LIBRARY_FILE_NAME"

export PATH="/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$RUST_DIRECTORY/target}"

rustup target add "$APPLE_SILICON_TARGET" "$INTEL_TARGET"

for target in "$APPLE_SILICON_TARGET" "$INTEL_TARGET"; do
  cargo build \
    --manifest-path "$RUST_DIRECTORY/Cargo.toml" \
    --release \
    --package "$BRIDGE_CRATE" \
    --target "$target"
done

mkdir -p "$NATIVE_DIRECTORY"
UNIVERSAL_LIBRARY="$NATIVE_DIRECTORY/$LIBRARY_FILE_NAME"
lipo -create \
  "$CARGO_TARGET_DIR/$APPLE_SILICON_TARGET/release/$LIBRARY_FILE_NAME" \
  "$CARGO_TARGET_DIR/$INTEL_TARGET/release/$LIBRARY_FILE_NAME" \
  -output "$UNIVERSAL_LIBRARY"
install_name_tool -id "$INSTALL_NAME" "$UNIVERSAL_LIBRARY"

echo "macos library: $UNIVERSAL_LIBRARY"

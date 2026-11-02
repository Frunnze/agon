#!/bin/sh
set -eu

SCRIPTS_DIRECTORY=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIRECTORY=$(dirname -- "$SCRIPTS_DIRECTORY")
RUST_DIRECTORY="$PROJECT_DIRECTORY/rust"
NATIVE_DIRECTORY="$PROJECT_DIRECTORY/app/linux/native"
BRIDGE_CRATE=orchestration-ffi
LIBRARY_FILE_NAME=liborchestration_ffi.so

export PATH="$HOME/.cargo/bin:$PATH"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$RUST_DIRECTORY/target}"

cargo build \
  --manifest-path "$RUST_DIRECTORY/Cargo.toml" \
  --release \
  --package "$BRIDGE_CRATE"

mkdir -p "$NATIVE_DIRECTORY"
cp "$CARGO_TARGET_DIR/release/$LIBRARY_FILE_NAME" \
  "$NATIVE_DIRECTORY/$LIBRARY_FILE_NAME"

echo "linux library: $NATIVE_DIRECTORY/$LIBRARY_FILE_NAME"

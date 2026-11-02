#!/bin/sh
set -eu

SCRIPTS_DIRECTORY=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIRECTORY=$(dirname -- "$SCRIPTS_DIRECTORY")
RUST_DIRECTORY="$PROJECT_DIRECTORY/rust"
JNI_LIBRARIES_DIRECTORY="$PROJECT_DIRECTORY/app/android/app/src/main/jniLibs"
BRIDGE_CRATE=orchestration-ffi
ANDROID_ABI=arm64-v8a
ANDROID_PLATFORM_LEVEL=24
LIBRARY_FILE_NAME=liborchestration_ffi.so

export PATH="/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
export CARGO_TARGET_DIR="$RUST_DIRECTORY/target"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/28.2.13676358}"

(
  cd "$RUST_DIRECTORY"
  cargo ndk \
    --manifest-path "$RUST_DIRECTORY/Cargo.toml" \
    --target "$ANDROID_ABI" \
    --platform "$ANDROID_PLATFORM_LEVEL" \
    --output-dir "$JNI_LIBRARIES_DIRECTORY" \
    build --release --no-default-features --package "$BRIDGE_CRATE"
)

find "$JNI_LIBRARIES_DIRECTORY/$ANDROID_ABI" -name '*.so' \
  ! -name "$LIBRARY_FILE_NAME" -delete

echo "android library: $JNI_LIBRARIES_DIRECTORY/$ANDROID_ABI/$LIBRARY_FILE_NAME"

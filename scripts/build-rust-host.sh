#!/bin/sh
set -eu

SCRIPTS_DIRECTORY=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIRECTORY=$(dirname -- "$SCRIPTS_DIRECTORY")
RUST_DIRECTORY="$PROJECT_DIRECTORY/rust"
BRIDGE_CRATE=orchestration-ffi
SERVER_CRATE=orchestration-server
NODE_CRATE=orchestration-node
NODE_HOST_PROGRAM=orchestration_node_host
BUILD_PROFILE_DIRECTORY=debug

export PATH="/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
export CARGO_TARGET_DIR="$RUST_DIRECTORY/target"

case "$(uname -s)" in
  Darwin) LIBRARY_FILE_NAME=liborchestration_ffi.dylib ;;
  Linux) LIBRARY_FILE_NAME=liborchestration_ffi.so ;;
  *) LIBRARY_FILE_NAME=orchestration_ffi.dll ;;
esac

cargo build \
  --manifest-path "$RUST_DIRECTORY/Cargo.toml" \
  --package "$BRIDGE_CRATE" \
  --package "$SERVER_CRATE" \
  --package "$NODE_CRATE"

OUTPUT_DIRECTORY="$CARGO_TARGET_DIR/$BUILD_PROFILE_DIRECTORY"
echo "bridge library: $OUTPUT_DIRECTORY/$LIBRARY_FILE_NAME"
echo "server program: $OUTPUT_DIRECTORY/$SERVER_CRATE"
echo "runner host program: $OUTPUT_DIRECTORY/$NODE_HOST_PROGRAM"

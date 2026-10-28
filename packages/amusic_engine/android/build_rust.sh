#!/bin/sh
# Usage: build_rust.sh <ndk-dir> <min-api> <abi>...
# Cross-compiles the Rust engine with the NDK's clang and drops the .so into
# src/main/jniLibs/<abi>/.
set -e

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo not found. Install Rust from https://rustup.rs" >&2
  exit 1
fi

NDK="$1"; API="$2"; shift 2
HERE="$(cd "$(dirname "$0")" && pwd)"
CRATE="$HERE/../rust"
export CARGO_TARGET_DIR="$CRATE/target"

case "$(uname -s)" in
  Darwin) HOST=darwin-x86_64 ;;
  Linux) HOST=linux-x86_64 ;;
  *) HOST=windows-x86_64 ;;
esac
BIN="$NDK/toolchains/llvm/prebuilt/$HOST/bin"

for abi in "$@"; do
  case "$abi" in
    arm64-v8a) target=aarch64-linux-android; clang="aarch64-linux-android$API-clang" ;;
    armeabi-v7a) target=armv7-linux-androideabi; clang="armv7a-linux-androideabi$API-clang" ;;
    x86_64) target=x86_64-linux-android; clang="x86_64-linux-android$API-clang" ;;
    *) echo "error: unsupported ABI $abi" >&2; exit 1 ;;
  esac
  if ! rustup target list --installed 2>/dev/null | grep -qx "$target"; then
    echo "error: Rust target $target is missing. Run: rustup target add $target" >&2
    exit 1
  fi
  upper="$(echo "$target" | tr 'a-z-' 'A-Z_')"
  export "CARGO_TARGET_${upper}_LINKER=$BIN/$clang"
  export "CC_$(echo "$target" | tr '-' '_')=$BIN/$clang"
  export "AR_$(echo "$target" | tr '-' '_')=$BIN/llvm-ar"
  cargo build --release --manifest-path "$CRATE/Cargo.toml" --target "$target"
  mkdir -p "$HERE/src/main/jniLibs/$abi"
  cp "$CRATE/target/$target/release/libamusic_engine.so" "$HERE/src/main/jniLibs/$abi/"
done

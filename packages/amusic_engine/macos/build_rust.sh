#!/bin/sh
# Builds the Rust engine for every architecture Xcode is building and merges
# them into ${BUILT_PRODUCTS_DIR}/libamusic_engine.a (force-loaded by the pod).
set -e

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo not found. Install Rust from https://rustup.rs" >&2
  exit 1
fi

CRATE="${PODS_TARGET_SRCROOT}/../rust"
OUT="${BUILT_PRODUCTS_DIR}/libamusic_engine.a"
export CARGO_TARGET_DIR="${CRATE}/target"
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"

LIBS=""
for arch in ${ARCHS:-$(uname -m)}; do
  case "$arch" in
    arm64) target=aarch64-apple-darwin ;;
    x86_64) target=x86_64-apple-darwin ;;
    *) echo "error: unsupported arch $arch" >&2; exit 1 ;;
  esac
  if ! rustup target list --installed 2>/dev/null | grep -qx "$target"; then
    echo "error: Rust target $target is missing. Run: rustup target add $target" >&2
    exit 1
  fi
  cargo build --release --manifest-path "${CRATE}/Cargo.toml" --target "$target"
  LIBS="$LIBS ${CRATE}/target/$target/release/libamusic_engine.a"
done

mkdir -p "${BUILT_PRODUCTS_DIR}"
# shellcheck disable=SC2086
lipo -create $LIBS -output "$OUT"

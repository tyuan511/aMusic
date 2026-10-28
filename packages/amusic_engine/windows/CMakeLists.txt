cmake_minimum_required(VERSION 3.14)
project(amusic_engine LANGUAGES C)

# Builds the Rust engine with cargo (MSVC toolchain) and ships the DLL next to
# the executable.
set(CRATE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../rust")
set(CARGO_OUT "${CMAKE_CURRENT_BINARY_DIR}/cargo")
set(ENGINE_LIB "${CARGO_OUT}/release/amusic_engine.dll")

add_custom_command(
  OUTPUT "${ENGINE_LIB}"
  COMMAND ${CMAKE_COMMAND} -E env CARGO_TARGET_DIR=${CARGO_OUT}
          cargo build --release --manifest-path "${CRATE_DIR}/Cargo.toml"
  DEPENDS "${CRATE_DIR}/Cargo.toml"
  COMMENT "Building the Rust audio engine"
  VERBATIM)
add_custom_target(amusic_engine_build ALL DEPENDS "${ENGINE_LIB}")

# Flutter copies these next to the executable.
set(amusic_engine_bundled_libraries "${ENGINE_LIB}" PARENT_SCOPE)

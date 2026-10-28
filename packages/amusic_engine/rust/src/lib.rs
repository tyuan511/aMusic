//! aMusic audio engine: decode, equalize, effect, limit, play.
//!
//! One Rust implementation for every platform; the Flutter app talks to it
//! through the C ABI in [`ffi`].

#[cfg(target_os = "android")]
mod android;
pub mod crypto;
pub mod decode;
pub mod dsp;
pub mod effects;
pub mod ffi;
pub mod ffi_tools;
mod hrir_data;
pub mod http;
pub mod limiter;
pub mod loudness;
pub mod palette;
pub mod pipeline;
pub mod player;
pub mod probe;
pub mod resample;
pub mod spectrum;
pub mod stretch;

pub use dsp::{peak_boost_db, response_db, Band, Equalizer};
pub use effects::{Effect, EffectChain};
pub use limiter::Limiter;
pub use pipeline::{EqConfig, Pipeline};
pub use player::{Player, Status};

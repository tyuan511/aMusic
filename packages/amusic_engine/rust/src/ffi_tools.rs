//! C ABI for the stateless helpers: NetEase encryption, cover palettes and tag
//! probing. Every call returns a heap buffer the caller releases with
//! [`amusic_buffer_free`]; a null return means failure.
//!
//! All numbers are little endian. Strings are `u32 length + UTF-8`.

use std::ffi::{c_char, CStr};
use std::path::Path;
use std::slice;

use crate::palette::{self, Swatch};
use crate::probe::{self, Probed};

fn into_raw(bytes: Vec<u8>, out_len: *mut usize) -> *mut u8 {
    let boxed = bytes.into_boxed_slice();
    // SAFETY: the caller passes a valid out pointer (or null, which we skip).
    unsafe {
        if let Some(len) = out_len.as_mut() {
            *len = boxed.len();
        }
    }
    Box::into_raw(boxed).cast::<u8>()
}

/// # Safety
/// `ptr`/`len` must be exactly what a tool call returned.
#[no_mangle]
pub unsafe extern "C" fn amusic_buffer_free(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        drop(Box::from_raw(slice::from_raw_parts_mut(ptr, len)));
    }
}

unsafe fn cstr(ptr: *const c_char) -> Option<&'static str> {
    if ptr.is_null() {
        return None;
    }
    CStr::from_ptr(ptr).to_str().ok()
}

fn put_str(out: &mut Vec<u8>, s: &str) {
    out.extend_from_slice(&(s.len() as u32).to_le_bytes());
    out.extend_from_slice(s.as_bytes());
}

/// eapi payload as UTF-8 hex text.
///
/// # Safety
/// `uri` and `json` are NUL terminated strings.
#[no_mangle]
pub unsafe extern "C" fn amusic_netease_eapi(
    uri: *const c_char,
    json: *const c_char,
    out_len: *mut usize,
) -> *mut u8 {
    let (Some(uri), Some(json)) = (cstr(uri), cstr(json)) else {
        return std::ptr::null_mut();
    };
    into_raw(crate::crypto::eapi(uri, json).into_bytes(), out_len)
}

/// weapi payload: `params`, a `\n`, then `encSecKey`. `secret` is 16 bytes.
///
/// # Safety
/// `json` is a NUL terminated string, `secret` points at 16 readable bytes.
#[no_mangle]
pub unsafe extern "C" fn amusic_netease_weapi(
    json: *const c_char,
    secret: *const u8,
    out_len: *mut usize,
) -> *mut u8 {
    let Some(json) = cstr(json) else {
        return std::ptr::null_mut();
    };
    if secret.is_null() {
        return std::ptr::null_mut();
    }
    let mut key = [0u8; 16];
    key.copy_from_slice(slice::from_raw_parts(secret, 16));
    let (params, sec) = crate::crypto::weapi(json, &key);
    into_raw(format!("{params}\n{sec}").into_bytes(), out_len)
}

fn argb(s: Option<&Swatch>) -> u32 {
    s.map_or(0, |s| {
        0xFF00_0000 | u32::from(s.rgb[0]) << 16 | u32::from(s.rgb[1]) << 8 | u32::from(s.rgb[2])
    })
}

/// Cover palette: 7 × `u32` ARGB (dominant, vibrant, light vibrant, dark
/// vibrant, muted, light muted, dark muted; 0 = none), then `u32 n` and `n`
/// ARGB swatches by population.
///
/// # Safety
/// `data` points at `len` readable bytes.
#[no_mangle]
pub unsafe extern "C" fn amusic_cover_palette(
    data: *const u8,
    len: usize,
    out_len: *mut usize,
) -> *mut u8 {
    if data.is_null() {
        return std::ptr::null_mut();
    }
    let Some(p) = palette::extract(slice::from_raw_parts(data, len)) else {
        return std::ptr::null_mut();
    };
    let mut out = Vec::new();
    for slot in [
        &p.dominant,
        &p.vibrant,
        &p.light_vibrant,
        &p.dark_vibrant,
        &p.muted,
        &p.light_muted,
        &p.dark_muted,
    ] {
        out.extend_from_slice(&argb(slot.as_ref()).to_le_bytes());
    }
    out.extend_from_slice(&(p.swatches.len() as u32).to_le_bytes());
    for s in &p.swatches {
        out.extend_from_slice(&argb(Some(s)).to_le_bytes());
    }
    into_raw(out, out_len)
}

fn encode_probe(p: &Probed) -> Vec<u8> {
    let mut out = vec![p.container as u8];
    out.extend_from_slice(&p.duration_us.to_le_bytes());
    out.extend_from_slice(&p.track_number.map_or(-1i32, |n| n as i32).to_le_bytes());
    out.extend_from_slice(&p.replay_gain_db.unwrap_or(f32::NAN).to_le_bytes());
    put_str(&mut out, &p.title);
    put_str(&mut out, &p.artist);
    put_str(&mut out, &p.album);
    out.extend_from_slice(&(p.cover.len() as u32).to_le_bytes());
    out.extend_from_slice(&p.cover);
    out
}

/// Tags and duration of the audio file at `path`: `u8 container`, `i64
/// duration µs`, `i32 track` (-1 none), `f32 replay gain dB` (NaN none),
/// title, artist, album, `u32 n + n` cover bytes. Never null for a valid path
/// (unreadable files give empty tags).
///
/// # Safety
/// `path` is a NUL terminated string.
#[no_mangle]
pub unsafe extern "C" fn amusic_probe_file(path: *const c_char, out_len: *mut usize) -> *mut u8 {
    let Some(path) = cstr(path) else {
        return std::ptr::null_mut();
    };
    into_raw(encode_probe(&probe::probe_file(Path::new(path))), out_len)
}

/// Same as [`amusic_probe_file`] for an in-memory file; `ext` hints the format.
///
/// # Safety
/// `data` points at `len` readable bytes, `ext` is a NUL terminated string.
#[no_mangle]
pub unsafe extern "C" fn amusic_probe_bytes(
    data: *const u8,
    len: usize,
    ext: *const c_char,
    out_len: *mut usize,
) -> *mut u8 {
    if data.is_null() {
        return std::ptr::null_mut();
    }
    let ext = cstr(ext).unwrap_or("").to_ascii_lowercase();
    let bytes = slice::from_raw_parts(data, len).to_vec();
    into_raw(encode_probe(&probe::probe_bytes(bytes, &ext)), out_len)
}

/// Calculates a normalised timeline spectrum envelope for an audio location.
/// The location may be a local path, `file://` URL, or supported HTTP URL.
/// The caller should run this helper away from the UI thread.
///
/// # Safety
/// `path` is a NUL terminated string and `out_len` is writable or null.
#[no_mangle]
pub unsafe extern "C" fn amusic_spectrum_file(
    path: *const c_char,
    bands: u32,
    out_len: *mut usize,
) -> *mut u8 {
    let Some(path) = cstr(path) else {
        return std::ptr::null_mut();
    };
    let Some(values) = crate::spectrum::analyze(path, bands as usize) else {
        return std::ptr::null_mut();
    };
    into_raw(values, out_len)
}

/// Integrated loudness of the audio file at `path`: writes LUFS to `out[0]` and
/// the linear sample peak to `out[1]`. Returns 0 on success, -1 otherwise. Reads
/// and decodes the whole file, so call it off the UI thread.
///
/// # Safety
/// `path` is a NUL terminated string, `out` points at two writable `f64`.
#[no_mangle]
pub unsafe extern "C" fn amusic_loudness_file(path: *const c_char, out: *mut f64) -> i32 {
    let (Some(path), false) = (cstr(path), out.is_null()) else {
        return -1;
    };
    match crate::loudness::analyze(Path::new(path)) {
        Some(l) => {
            *out = l.lufs;
            *out.add(1) = l.peak;
            0
        }
        None => -1,
    }
}

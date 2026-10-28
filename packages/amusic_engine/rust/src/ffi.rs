//! C ABI for the Flutter side (`dart:ffi`). Every function takes the handle
//! returned by [`amusic_player_new`]; a null handle is ignored.
//!
//! Strings are UTF-8, NUL terminated. Nothing here blocks on I/O: `load` and
//! `set_next` return at once and the result shows up in [`amusic_player_status`]
//! (`state`, `load_seq`) and [`amusic_player_take_error`].

use std::cell::RefCell;
use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;

use crate::dsp::Band;
use crate::effects::Effect;
use crate::pipeline::EqConfig;
use crate::player::{Player, Status};

thread_local! {
    static LAST_ERROR: RefCell<CString> = RefCell::new(CString::default());
}

/// Handles that are still alive. A Flutter hot restart resets Dart's state but
/// leaves this library loaded, so players made before it would play on forever;
/// [`amusic_player_free_all`] lets the new isolate reap them.
static LIVE: Mutex<Vec<usize>> = Mutex::new(Vec::new());

fn live() -> std::sync::MutexGuard<'static, Vec<usize>> {
    LIVE.lock().unwrap_or_else(|e| e.into_inner())
}

fn set_error(msg: &str) {
    let msg = CString::new(msg.replace('\0', " ")).unwrap_or_default();
    LAST_ERROR.with(|e| *e.borrow_mut() = msg);
}

/// Message of the last failed call on this thread (valid until the next call).
#[no_mangle]
pub extern "C" fn amusic_last_error() -> *const c_char {
    LAST_ERROR.with(|e| e.borrow().as_ptr())
}

#[no_mangle]
pub extern "C" fn amusic_player_new() -> *mut Player {
    match Player::new() {
        Ok(p) => {
            let raw = Box::into_raw(Box::new(p));
            live().push(raw as usize);
            raw
        }
        Err(e) => {
            set_error(&e);
            std::ptr::null_mut()
        }
    }
}

/// # Safety
/// `p` must come from [`amusic_player_new`] and not be used afterwards.
#[no_mangle]
pub unsafe extern "C" fn amusic_player_free(p: *mut Player) {
    if !p.is_null() {
        live().retain(|&h| h != p as usize);
        drop(Box::from_raw(p));
    }
}

/// Frees every player that was never freed (leftovers of a previous Dart
/// isolate after a hot restart). Call before creating the first player.
///
/// # Safety
/// No handle returned earlier may be used afterwards.
#[no_mangle]
pub unsafe extern "C" fn amusic_player_free_all() {
    let stale: Vec<usize> = std::mem::take(&mut *live());
    for h in stale {
        drop(Box::from_raw(h as *mut Player));
    }
}

fn with<R>(p: *mut Player, default: R, f: impl FnOnce(&Player) -> R) -> R {
    // SAFETY: the caller owns the handle and serialises calls (Dart isolate).
    match unsafe { p.as_ref() } {
        Some(player) => f(player),
        None => default,
    }
}

unsafe fn text(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }
    CStr::from_ptr(ptr).to_str().ok().map(str::to_owned)
}

/// Starts loading `url` (path, `file://` or `http://`), seeking to
/// `start_secs` once opened. Returns 0 if the request was accepted.
///
/// # Safety
/// `url` must be a valid NUL terminated string.
#[no_mangle]
pub unsafe extern "C" fn amusic_player_load(
    p: *mut Player,
    url: *const c_char,
    start_secs: f64,
) -> i32 {
    let Some(url) = text(url) else {
        set_error("invalid url");
        return -1;
    };
    with(p, -2, |pl| {
        pl.load(&url, start_secs);
        0
    })
}

/// Queues the track after the current one for a gapless start; null clears it.
///
/// # Safety
/// `url` must be null or a valid NUL terminated string.
#[no_mangle]
pub unsafe extern "C" fn amusic_player_set_next(p: *mut Player, url: *const c_char) {
    let url = text(url);
    with(p, (), |pl| pl.set_next(url.as_deref()));
}

#[no_mangle]
pub extern "C" fn amusic_player_play(p: *mut Player) {
    with(p, (), |pl| pl.play());
}

#[no_mangle]
pub extern "C" fn amusic_player_pause(p: *mut Player) {
    with(p, (), |pl| pl.pause());
}

#[no_mangle]
pub extern "C" fn amusic_player_stop(p: *mut Player) {
    with(p, (), |pl| pl.stop());
}

#[no_mangle]
pub extern "C" fn amusic_player_seek(p: *mut Player, secs: f64) {
    with(p, (), |pl| pl.seek(secs));
}

#[no_mangle]
pub extern "C" fn amusic_player_set_volume(p: *mut Player, volume: f32) {
    with(p, (), |pl| pl.set_volume(volume));
}

#[no_mangle]
pub extern "C" fn amusic_player_set_speed(p: *mut Player, speed: f64) {
    with(p, (), |pl| pl.set_speed(speed));
}

/// Applies the equalizer and sound effect: `count` peaking bands, a software
/// gain in dB, the limiter switch and a DSP effect (0 none, 1 3D surround,
/// 2 360 rotation, 3 LiveHouse, 4 exciter, 5 chorus, 8 echo, 9 dream). `bands` may be null when `count`
/// is 0.
///
/// # Safety
/// `bands` must point to `count` valid [`Band`]s.
#[no_mangle]
pub unsafe extern "C" fn amusic_player_set_eq(
    p: *mut Player,
    bands: *const Band,
    count: usize,
    gain_db: f32,
    limiter: bool,
    effect: u32,
) {
    let bands = if bands.is_null() || count == 0 {
        Vec::new()
    } else {
        std::slice::from_raw_parts(bands, count).to_vec()
    };
    with(p, (), |pl| {
        pl.set_eq(EqConfig {
            bands,
            gain_db,
            limiter,
            effect: Effect::from_u32(effect),
        })
    });
}

/// What the UI polls. `state`: 0 idle, 1 loading, 2 ready, 3 ended, 4 error.
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct AmusicStatus {
    pub state: u32,
    pub playing: bool,
    pub position: f64,
    /// Negative when unknown.
    pub duration: f64,
    pub advance_seq: u64,
    pub load_seq: u64,
}

impl From<Status> for AmusicStatus {
    fn from(s: Status) -> Self {
        Self {
            state: s.state,
            playing: s.playing,
            position: s.position,
            duration: s.duration,
            advance_seq: s.advance_seq,
            load_seq: s.load_seq,
        }
    }
}

/// # Safety
/// `out` must point to a writable [`AmusicStatus`].
#[no_mangle]
pub unsafe extern "C" fn amusic_player_status(p: *mut Player, out: *mut AmusicStatus) {
    if out.is_null() {
        return;
    }
    let status = with(p, None, |pl| Some(pl.status()));
    *out = status.map(Into::into).unwrap_or(AmusicStatus {
        state: 0,
        playing: false,
        position: 0.0,
        duration: -1.0,
        advance_seq: 0,
        load_seq: 0,
    });
}

/// Copies the last error message (and clears it) into `buf`; returns its
/// length, 0 when there was none. The result is always NUL terminated.
///
/// # Safety
/// `buf` must have room for `cap` bytes.
#[no_mangle]
pub unsafe extern "C" fn amusic_player_take_error(
    p: *mut Player,
    buf: *mut c_char,
    cap: usize,
) -> usize {
    let msg = with(p, String::new(), |pl| pl.take_error());
    if buf.is_null() || cap == 0 {
        return msg.len();
    }
    let n = msg.len().min(cap - 1);
    std::ptr::copy_nonoverlapping(msg.as_ptr(), buf as *mut u8, n);
    *buf.add(n) = 0;
    n
}

#[no_mangle]
pub extern "C" fn amusic_player_sample_rate(p: *mut Player) -> u32 {
    with(p, 0, |pl| pl.sample_rate())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn null_handles_are_harmless() {
        let null = std::ptr::null_mut();
        amusic_player_play(null);
        amusic_player_seek(null, 1.0);
        amusic_player_set_speed(null, 1.5);
        let mut st = std::mem::MaybeUninit::<AmusicStatus>::uninit();
        unsafe {
            amusic_player_status(null, st.as_mut_ptr());
            let st = st.assume_init();
            assert_eq!(st.state, 0);
            assert_eq!(st.duration, -1.0);
            amusic_player_free(null);
        }
    }

    #[test]
    fn load_rejects_a_null_url() {
        let rc = unsafe { amusic_player_load(std::ptr::null_mut(), std::ptr::null(), 0.0) };
        assert_eq!(rc, -1);
        let msg = unsafe { CStr::from_ptr(amusic_last_error()) };
        assert_eq!(msg.to_str().unwrap(), "invalid url");
    }

    #[test]
    fn layouts_are_c_compatible() {
        assert_eq!(std::mem::size_of::<Band>(), 12);
        assert_eq!(std::mem::size_of::<AmusicStatus>(), 40);
        assert_eq!(std::mem::align_of::<AmusicStatus>(), 8);
    }
}

/// Loudness normalisation of the playing track, in dB.
#[no_mangle]
pub extern "C" fn amusic_player_set_gain(p: *mut Player, db: f32) {
    with(p, (), |pl| pl.set_gain_db(db));
}

/// Gain of the queued track, applied where it starts. NaN clears it.
#[no_mangle]
pub extern "C" fn amusic_player_set_next_gain(p: *mut Player, db: f32) {
    with(p, (), |pl| pl.set_next_gain_db(db));
}

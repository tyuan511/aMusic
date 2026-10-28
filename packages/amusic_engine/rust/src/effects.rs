//! One tap sound effects that need real DSP (the EQ-only ones are just band
//! lists on the Dart side): headphone spatializer, rotating 360 degree image,
//! live-room reverb and a harmonic exciter.
//!
//! Everything works on interleaved stereo `f32` at the device rate and is
//! allocation free after construction, so it can run in the audio callback.

use std::f64::consts::PI;

/// Which effect is on. The numbers are the C ABI values.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
#[repr(u32)]
pub enum Effect {
    #[default]
    None = 0,
    /// Headphone spatializer: wider image, cross-feed, a touch of room.
    Surround3d = 1,
    /// The stereo image circles the listener's head every 8 seconds.
    Rotate360 = 2,
    /// A small music hall: pre-delay, early reflections, dense tail.
    LiveHouse = 3,
    /// Adds high harmonics for a clearer, airier top end.
    Exciter = 4,
}

impl Effect {
    pub fn from_u32(v: u32) -> Self {
        match v {
            1 => Self::Surround3d,
            2 => Self::Rotate360,
            3 => Self::LiveHouse,
            4 => Self::Exciter,
            _ => Self::None,
        }
    }
}

// ---------------------------------------------------------------- biquad

#[derive(Clone, Copy, Default)]
struct Biquad {
    b0: f64,
    b1: f64,
    b2: f64,
    a1: f64,
    a2: f64,
    z1: f64,
    z2: f64,
}

impl Biquad {
    fn from_coeffs(b0: f64, b1: f64, b2: f64, a0: f64, a1: f64, a2: f64) -> Self {
        Self {
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0,
            z1: 0.0,
            z2: 0.0,
        }
    }

    fn lowpass(fs: f64, f: f64, q: f64) -> Self {
        let w = 2.0 * PI * f / fs;
        let (c, a) = (w.cos(), w.sin() / (2.0 * q));
        Self::from_coeffs(
            (1.0 - c) / 2.0,
            1.0 - c,
            (1.0 - c) / 2.0,
            1.0 + a,
            -2.0 * c,
            1.0 - a,
        )
    }

    fn highpass(fs: f64, f: f64, q: f64) -> Self {
        let w = 2.0 * PI * f / fs;
        let (c, a) = (w.cos(), w.sin() / (2.0 * q));
        Self::from_coeffs(
            (1.0 + c) / 2.0,
            -(1.0 + c),
            (1.0 + c) / 2.0,
            1.0 + a,
            -2.0 * c,
            1.0 - a,
        )
    }

    fn high_shelf(fs: f64, f: f64, gain_db: f64) -> Self {
        let a = 10f64.powf(gain_db / 40.0);
        let w = 2.0 * PI * f / fs;
        let (c, s) = (w.cos(), w.sin());
        let alpha = s / 2.0 * 2f64.sqrt(); // shelf slope 1
        let k = 2.0 * a.sqrt() * alpha;
        Self::from_coeffs(
            a * ((a + 1.0) + (a - 1.0) * c + k),
            -2.0 * a * ((a - 1.0) + (a + 1.0) * c),
            a * ((a + 1.0) + (a - 1.0) * c - k),
            (a + 1.0) - (a - 1.0) * c + k,
            2.0 * ((a - 1.0) - (a + 1.0) * c),
            (a + 1.0) - (a - 1.0) * c - k,
        )
    }

    #[inline]
    fn process(&mut self, x: f32) -> f32 {
        let x = x as f64;
        let y = self.b0 * x + self.z1;
        self.z1 = self.b1 * x - self.a1 * y + self.z2;
        self.z2 = self.b2 * x - self.a2 * y;
        y as f32
    }
}

/// Fixed length delay line with an integer tap.
#[derive(Clone)]
struct Delay {
    buf: Vec<f32>,
    idx: usize,
}

impl Delay {
    fn new(len: usize) -> Self {
        Self {
            buf: vec![0.0; len.max(1)],
            idx: 0,
        }
    }

    /// Writes `x` and returns the sample written `len` frames ago.
    #[inline]
    fn push(&mut self, x: f32) -> f32 {
        let out = self.buf[self.idx];
        self.buf[self.idx] = x;
        self.idx += 1;
        if self.idx == self.buf.len() {
            self.idx = 0;
        }
        out
    }
}

// --------------------------------------------------------------- reverb

struct Comb {
    buf: Vec<f32>,
    idx: usize,
    store: f32,
}

struct Allpass {
    buf: Vec<f32>,
    idx: usize,
}

/// Freeverb (public domain, Jezar): eight damped combs and four allpasses per
/// channel. Returns only the wet signal; the caller mixes.
struct Reverb {
    comb_l: Vec<Comb>,
    comb_r: Vec<Comb>,
    all_l: Vec<Allpass>,
    all_r: Vec<Allpass>,
    feedback: f32,
    damp: f32,
    predelay: Delay,
}

const COMB_TUNING: [usize; 8] = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
const ALLPASS_TUNING: [usize; 4] = [556, 441, 341, 225];
const STEREO_SPREAD: usize = 23;

impl Reverb {
    /// `room` 0..1 sets the decay, `damp` 0..1 how fast highs die.
    fn new(fs: u32, room: f32, damp: f32, predelay_ms: f32) -> Self {
        let scale = fs as f64 / 44100.0;
        let len = |n: usize| ((n as f64 * scale).round() as usize).max(1);
        let comb = |n: usize| Comb {
            buf: vec![0.0; len(n)],
            idx: 0,
            store: 0.0,
        };
        let all = |n: usize| Allpass {
            buf: vec![0.0; len(n)],
            idx: 0,
        };
        Self {
            comb_l: COMB_TUNING.iter().map(|&n| comb(n)).collect(),
            comb_r: COMB_TUNING
                .iter()
                .map(|&n| comb(n + STEREO_SPREAD))
                .collect(),
            all_l: ALLPASS_TUNING.iter().map(|&n| all(n)).collect(),
            all_r: ALLPASS_TUNING
                .iter()
                .map(|&n| all(n + STEREO_SPREAD))
                .collect(),
            feedback: room * 0.28 + 0.7,
            damp: damp * 0.4,
            predelay: Delay::new((fs as f32 * predelay_ms / 1000.0) as usize),
        }
    }

    #[inline]
    fn run_comb(c: &mut Comb, input: f32, damp: f32, feedback: f32) -> f32 {
        let out = c.buf[c.idx];
        c.store = out * (1.0 - damp) + c.store * damp;
        c.buf[c.idx] = input + c.store * feedback;
        // Wrap by comparison: `%` by a non power of two is a real division,
        // and this runs 24 times per frame.
        c.idx += 1;
        if c.idx == c.buf.len() {
            c.idx = 0;
        }
        out
    }

    #[inline]
    fn run_allpass(a: &mut Allpass, input: f32) -> f32 {
        let buffered = a.buf[a.idx];
        let out = buffered - input;
        a.buf[a.idx] = input + buffered * 0.5;
        a.idx += 1;
        if a.idx == a.buf.len() {
            a.idx = 0;
        }
        out
    }

    /// Wet output for one input frame.
    #[inline]
    fn process(&mut self, l: f32, r: f32) -> (f32, f32) {
        let input = self.predelay.push((l + r) * 0.015);
        let (mut out_l, mut out_r) = (0.0, 0.0);
        for c in self.comb_l.iter_mut() {
            out_l += Self::run_comb(c, input, self.damp, self.feedback);
        }
        for c in self.comb_r.iter_mut() {
            out_r += Self::run_comb(c, input, self.damp, self.feedback);
        }
        for a in self.all_l.iter_mut() {
            out_l = Self::run_allpass(a, out_l);
        }
        for a in self.all_r.iter_mut() {
            out_r = Self::run_allpass(a, out_r);
        }
        (out_l, out_r)
    }
}

// ------------------------------------------------------------ the effects

struct Surround3d {
    side_shelf: Biquad,
    cross_l: Biquad,
    cross_r: Biquad,
    delay_l: Delay,
    delay_r: Delay,
    reverb: Reverb,
}

impl Surround3d {
    fn new(fs: u32) -> Self {
        let f = fs as f64;
        Self {
            side_shelf: Biquad::high_shelf(f, 3500.0, 3.0),
            cross_l: Biquad::lowpass(f, 700.0, 0.7),
            cross_r: Biquad::lowpass(f, 700.0, 0.7),
            // ~0.27 ms interaural delay.
            delay_l: Delay::new((f * 0.00027).round() as usize),
            delay_r: Delay::new((f * 0.00027).round() as usize),
            reverb: Reverb::new(fs, 0.55, 0.55, 8.0),
        }
    }

    #[inline]
    fn process(&mut self, l: f32, r: f32) -> (f32, f32) {
        // Widen: the difference signal gets louder and brighter.
        let m = (l + r) * 0.5;
        let s = self.side_shelf.process((l - r) * 0.5) * 1.6;
        let (wl, wr) = (m + s, m - s);
        // Cross-feed: each ear also hears a darker, slightly late copy of the
        // opposite channel, like speakers in a room.
        let cf_l = self.cross_l.process(self.delay_l.push(wr));
        let cf_r = self.cross_r.process(self.delay_r.push(wl));
        let (ol, or) = (wl + 0.22 * cf_l, wr + 0.22 * cf_r);
        // A little room around the head.
        let (rl, rr) = self.reverb.process(ol, or);
        (ol * 0.95 + rl * 0.28, or * 0.95 + rr * 0.28)
    }
}

struct Rotate360 {
    fs: f64,
    phase: f64,
    step: f64,
    line: Vec<f32>,
    pos: usize,
    shadow_l: f32,
    shadow_r: f32,
    behind: Biquad,
    reverb: Reverb,
    /// Frames until the trigonometry below is recomputed.
    countdown: u32,
    itd_l: f64,
    itd_r: f64,
    gain_l: f32,
    gain_r: f32,
    shadow_k_l: f32,
    shadow_k_r: f32,
    back: f32,
}

/// Seconds for one full turn.
const ROTATE_PERIOD: f64 = 8.0;
/// Largest interaural time difference, seconds.
const MAX_ITD: f64 = 0.0006;
/// Delay line length for the interaural delay; a power of two so wrapping is a mask.
const ROTATE_LINE: usize = 256;
/// The pan position moves by well under a degree in this many frames, so the
/// sin / cos / exp work is done once per block instead of once per sample.
const ROTATE_BLOCK: u32 = 16;

impl Rotate360 {
    fn new(fs: u32) -> Self {
        let f = fs as f64;
        Self {
            fs: f,
            phase: 0.0,
            step: 2.0 * PI / (ROTATE_PERIOD * f),
            line: vec![0.0; ROTATE_LINE],
            pos: 0,
            shadow_l: 0.0,
            shadow_r: 0.0,
            behind: Biquad::lowpass(f, 5000.0, 0.7),
            reverb: Reverb::new(fs, 0.45, 0.6, 5.0),
            countdown: 0,
            itd_l: 0.0,
            itd_r: 0.0,
            gain_l: 1.0,
            gain_r: 1.0,
            shadow_k_l: 1.0,
            shadow_k_r: 1.0,
            back: 0.0,
        }
    }

    /// Recomputes everything that depends on the current azimuth.
    fn update_position(&mut self) {
        let p = self.phase.sin(); // -1 left .. +1 right
        let front = self.phase.cos();
        self.back = (-front).max(0.0) as f32;
        // Interaural time difference: the far ear hears it later.
        let itd = p.abs() * MAX_ITD * self.fs;
        (self.itd_l, self.itd_r) = if p > 0.0 { (itd, 0.0) } else { (0.0, itd) };
        // Interaural level difference (constant power).
        let ang = (p + 1.0) * PI / 4.0;
        self.gain_l = (ang.cos() * std::f64::consts::SQRT_2) as f32;
        self.gain_r = (ang.sin() * std::f64::consts::SQRT_2) as f32;
        // Head shadow: the far ear loses highs.
        let k = |fc: f64| (1.0 - (-2.0 * PI * fc / self.fs).exp()) as f32;
        self.shadow_k_l = k(if p > 0.0 {
            20000.0 - p * 15000.0
        } else {
            20000.0
        });
        self.shadow_k_r = k(if p < 0.0 {
            20000.0 + p * 15000.0
        } else {
            20000.0
        });
    }

    #[inline]
    fn tap(&self, delay: f64) -> f32 {
        let at = self.pos as f64 - delay;
        let at = if at < 0.0 {
            at + ROTATE_LINE as f64
        } else {
            at
        };
        let floor = at.floor();
        let i = floor as usize & (ROTATE_LINE - 1);
        let frac = (at - floor) as f32;
        let a = self.line[i];
        let b = self.line[(i + 1) & (ROTATE_LINE - 1)];
        a + (b - a) * frac
    }

    #[inline]
    fn process(&mut self, l: f32, r: f32) -> (f32, f32) {
        if self.countdown == 0 {
            self.update_position();
            self.countdown = ROTATE_BLOCK;
        }
        self.countdown -= 1;

        let m = (l + r) * 0.5;
        let s = (l - r) * 0.5;

        // Sources behind the head are duller.
        let m = m * (1.0 - 0.6 * self.back) + self.behind.process(m) * 0.6 * self.back;

        self.line[self.pos] = m;
        let (ml, mr) = (self.tap(self.itd_l), self.tap(self.itd_r));
        self.pos = (self.pos + 1) & (ROTATE_LINE - 1);

        self.shadow_l += (ml - self.shadow_l) * self.shadow_k_l;
        self.shadow_r += (mr - self.shadow_r) * self.shadow_k_r;

        // The stereo-only part stays around the head as ambience.
        let ol = self.shadow_l * self.gain_l + s * 0.7;
        let or = self.shadow_r * self.gain_r - s * 0.7;
        self.phase += self.step;
        if self.phase > 2.0 * PI {
            self.phase -= 2.0 * PI;
        }
        let (rl, rr) = self.reverb.process(ol, or);
        (ol + rl * 0.35, or + rr * 0.35)
    }
}

struct LiveHouse {
    reverb: Reverb,
    wet_hp_l: Biquad,
    wet_hp_r: Biquad,
    presence: Biquad,
    presence_r: Biquad,
    early_l: Delay,
    early_r: Delay,
    fs: f64,
}

impl LiveHouse {
    fn new(fs: u32) -> Self {
        let f = fs as f64;
        let len = |ms: f64| (f * ms / 1000.0).round() as usize;
        Self {
            reverb: Reverb::new(fs, 0.82, 0.3, 18.0),
            wet_hp_l: Biquad::highpass(f, 160.0, 0.7),
            wet_hp_r: Biquad::highpass(f, 160.0, 0.7),
            presence: Biquad::high_shelf(f, 6000.0, 2.0),
            presence_r: Biquad::high_shelf(f, 6000.0, 2.0),
            // Room slap: a few discrete reflections off the walls.
            early_l: Delay::new(len(41.0)),
            early_r: Delay::new(len(29.0)),
            fs: f,
        }
    }

    #[inline]
    fn process(&mut self, l: f32, r: f32) -> (f32, f32) {
        let _ = self.fs;
        let (wl, wr) = self.reverb.process(l, r);
        let wl = self.wet_hp_l.process(wl);
        let wr = self.wet_hp_r.process(wr);
        let er = self.early_l.push(r) * 0.16;
        let el = self.early_r.push(l) * 0.16;
        let ol = l * 0.86 + wl * 0.95 + el;
        let or = r * 0.86 + wr * 0.95 + er;
        (self.presence.process(ol), self.presence_r.process(or))
    }
}

struct Exciter {
    pre: [Biquad; 2],
    post: [Biquad; 2],
}

impl Exciter {
    fn new(fs: u32) -> Self {
        let f = fs as f64;
        Self {
            pre: [
                Biquad::highpass(f, 3500.0, 0.7),
                Biquad::highpass(f, 3500.0, 0.7),
            ],
            post: [
                Biquad::highpass(f, 6500.0, 0.7),
                Biquad::highpass(f, 6500.0, 0.7),
            ],
        }
    }

    #[inline]
    fn process(&mut self, l: f32, r: f32) -> (f32, f32) {
        let mut out = [l, r];
        for (ch, x) in out.iter_mut().enumerate() {
            let hi = self.pre[ch].process(*x);
            // Odd harmonics from a soft clipper, keeping only the new highs.
            let harm = self.post[ch].process((hi * 4.0).tanh() * 0.25);
            *x += harm * 0.45;
        }
        (out[0], out[1])
    }
}

/// The active effect plus its state.
pub struct EffectChain {
    fs: u32,
    kind: Effect,
    surround: Option<Surround3d>,
    rotate: Option<Rotate360>,
    live: Option<LiveHouse>,
    exciter: Option<Exciter>,
}

impl EffectChain {
    pub fn new(fs: u32) -> Self {
        Self {
            fs,
            kind: Effect::None,
            surround: None,
            rotate: None,
            live: None,
            exciter: None,
        }
    }

    pub fn effect(&self) -> Effect {
        self.kind
    }

    /// Switches effect; the previous one's state (and reverb tail) is dropped.
    pub fn set_effect(&mut self, kind: Effect) {
        if kind == self.kind {
            return;
        }
        self.kind = kind;
        self.surround = (kind == Effect::Surround3d).then(|| Surround3d::new(self.fs));
        self.rotate = (kind == Effect::Rotate360).then(|| Rotate360::new(self.fs));
        self.live = (kind == Effect::LiveHouse).then(|| LiveHouse::new(self.fs));
        self.exciter = (kind == Effect::Exciter).then(|| Exciter::new(self.fs));
    }

    /// Processes interleaved stereo in place.
    pub fn process(&mut self, buf: &mut [f32]) {
        macro_rules! run {
            ($fx:expr) => {
                if let Some(fx) = $fx.as_mut() {
                    for f in buf.chunks_exact_mut(2) {
                        let (l, r) = fx.process(f[0], f[1]);
                        f[0] = l;
                        f[1] = r;
                    }
                }
            };
        }
        match self.kind {
            Effect::None => {}
            Effect::Surround3d => run!(self.surround),
            Effect::Rotate360 => run!(self.rotate),
            Effect::LiveHouse => run!(self.live),
            Effect::Exciter => run!(self.exciter),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const FS: u32 = 44100;

    fn tone(freq: f64, secs: f64, l_gain: f32, r_gain: f32) -> Vec<f32> {
        let n = (FS as f64 * secs) as usize;
        (0..n)
            .flat_map(|i| {
                let v = (2.0 * PI * freq * i as f64 / FS as f64).sin() as f32 * 0.4;
                [v * l_gain, v * r_gain]
            })
            .collect()
    }

    /// Deterministic broadband noise; pure tones make comb filters resonate
    /// differently per channel, which says nothing about real music.
    fn noise(secs: f64, l_gain: f32, r_gain: f32) -> Vec<f32> {
        let mut state = 0x2545F491u32;
        let n = (FS as f64 * secs) as usize;
        (0..n)
            .flat_map(|_| {
                state = state.wrapping_mul(1664525).wrapping_add(1013904223);
                let v = ((state >> 8) as f32 / 8388608.0 - 1.0) * 0.3;
                [v * l_gain, v * r_gain]
            })
            .collect()
    }

    fn run(effect: Effect, input: &[f32]) -> Vec<f32> {
        let mut chain = EffectChain::new(FS);
        chain.set_effect(effect);
        let mut out = input.to_vec();
        chain.process(&mut out);
        out
    }

    fn rms(buf: &[f32], ch: usize) -> f64 {
        let v: Vec<f64> = buf.chunks_exact(2).map(|f| f[ch] as f64).collect();
        (v.iter().map(|x| x * x).sum::<f64>() / v.len().max(1) as f64).sqrt()
    }

    /// Magnitude of `freq` in channel `ch` (Goertzel).
    fn goertzel(buf: &[f32], ch: usize, freq: f64) -> f64 {
        let w = 2.0 * PI * freq / FS as f64;
        let coeff = 2.0 * w.cos();
        let (mut s1, mut s2) = (0.0f64, 0.0f64);
        for f in buf.chunks_exact(2) {
            let s = f[ch] as f64 + coeff * s1 - s2;
            s2 = s1;
            s1 = s;
        }
        let n = (buf.len() / 2) as f64;
        (s1 * s1 + s2 * s2 - coeff * s1 * s2).sqrt() * 2.0 / n
    }

    #[test]
    fn none_is_bit_exact() {
        let input = tone(440.0, 0.2, 1.0, 1.0);
        assert_eq!(run(Effect::None, &input), input);
    }

    #[test]
    fn every_effect_is_finite_and_bounded_on_loud_input() {
        let input = tone(220.0, 2.0, 1.0, 0.7);
        for e in [
            Effect::Surround3d,
            Effect::Rotate360,
            Effect::LiveHouse,
            Effect::Exciter,
        ] {
            let out = run(e, &input);
            assert!(
                out.iter().all(|s| s.is_finite() && s.abs() < 4.0),
                "{e:?} blew up"
            );
        }
    }

    #[test]
    fn surround_widens_the_image_and_keeps_the_centre() {
        // Mono in the middle stays in the middle.
        let mono = noise(2.0, 1.0, 1.0);
        let out = run(Effect::Surround3d, &mono);
        let (l, r) = (rms(&out[out.len() / 2..], 0), rms(&out[out.len() / 2..], 1));
        assert!((l / r - 1.0).abs() < 0.08, "mono drifted: {l} vs {r}");

        // A hard-left source leaks to the right ear (cross-feed / ambience) and
        // the side content is louder than before.
        let left = noise(2.0, 1.0, 0.0);
        let out = run(Effect::Surround3d, &left);
        let tail = &out[out.len() / 2..];
        assert!(rms(tail, 1) > 0.01, "no cross-feed");
        let side_in = {
            let t = &left[left.len() / 2..];
            t.chunks_exact(2)
                .map(|f| ((f[0] - f[1]) * 0.5) as f64)
                .map(|x| x * x)
                .sum::<f64>()
        };
        let side_out = tail
            .chunks_exact(2)
            .map(|f| ((f[0] - f[1]) * 0.5) as f64)
            .map(|x| x * x)
            .sum::<f64>();
        assert!(
            side_out > side_in * 1.1,
            "side energy {side_out} vs {side_in}"
        );
    }

    #[test]
    fn rotation_moves_a_centred_source_around_the_head() {
        let secs = 8.0;
        let mono = tone(1000.0, secs, 1.0, 1.0);
        let out = run(Effect::Rotate360, &mono);
        // Level difference between ears over 0.25 s windows.
        let win = (FS as f64 * 0.25) as usize * 2;
        let balance: Vec<f64> = out
            .chunks(win)
            .filter(|c| c.len() == win)
            .map(|c| 20.0 * (rms(c, 0) / rms(c, 1).max(1e-9)).log10())
            .collect();
        let max = balance.iter().cloned().fold(f64::MIN, f64::max);
        let min = balance.iter().cloned().fold(f64::MAX, f64::min);
        assert!(
            max > 4.0 && min < -4.0,
            "balance only swung {min:.1}..{max:.1} dB"
        );
        // It comes back: the first and last windows (a full turn apart) match.
        assert!((balance[0] - balance[balance.len() - 1]).abs() < 3.0);
        // Overall level stays roughly constant.
        let (a, b) = (
            rms(&mono, 0),
            (rms(&out, 0).powi(2) + rms(&out, 1).powi(2)).sqrt() / 2f64.sqrt(),
        );
        assert!((20.0 * (b / a).log10()).abs() < 4.0, "level {a} -> {b}");
    }

    #[test]
    fn live_house_adds_a_decaying_tail() {
        let mut input = vec![0.0f32; FS as usize * 2 * 2];
        input[0] = 0.9;
        input[1] = 0.9;
        let out = run(Effect::LiveHouse, &input);
        let second = |from: f64, to: f64| {
            let (a, b) = (
                (FS as f64 * from) as usize * 2,
                (FS as f64 * to) as usize * 2,
            );
            rms(&out[a..b], 0)
        };
        let early = second(0.05, 0.25);
        let later = second(0.5, 0.7);
        let late = second(1.5, 1.7);
        assert!(early > 1e-4, "no reverb tail at all");
        assert!(later > 1e-5, "tail too short: {later}");
        assert!(
            early > later && later > late,
            "tail does not decay: {early} {later} {late}"
        );
    }

    #[test]
    fn exciter_creates_high_harmonics_and_leaves_bass_alone() {
        let hi = tone(3000.0, 1.0, 1.0, 1.0);
        let out = run(Effect::Exciter, &hi);
        let (before, after) = (goertzel(&hi, 0, 9000.0), goertzel(&out, 0, 9000.0));
        assert!(
            before < 1e-3 && after > 0.004,
            "9 kHz harmonic {before} -> {after}"
        );

        let bass = tone(200.0, 1.0, 1.0, 1.0);
        let out = run(Effect::Exciter, &bass);
        let diff: f64 = bass
            .iter()
            .zip(&out)
            .map(|(a, b)| ((a - b) as f64).abs())
            .sum::<f64>()
            / bass.len() as f64;
        assert!(diff < 0.005, "bass changed by {diff}");
    }

    #[test]
    fn switching_effects_resets_state() {
        let mut chain = EffectChain::new(FS);
        chain.set_effect(Effect::LiveHouse);
        let mut loud = tone(440.0, 0.5, 1.0, 1.0);
        chain.process(&mut loud);
        chain.set_effect(Effect::Exciter);
        chain.set_effect(Effect::None);
        let mut silent = vec![0.0f32; 4096];
        chain.process(&mut silent);
        assert!(silent.iter().all(|&s| s == 0.0), "old tail leaked");
    }
}

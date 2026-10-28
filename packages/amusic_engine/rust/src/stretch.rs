//! Pitch-preserving time stretch (WSOLA) for the playback speed control.
//!
//! Frames of 30 ms are cut from the input at a hop of `speed * 15 ms`, each
//! start nudged by up to +-7 ms to the position whose waveform best continues
//! the previous frame, then overlap-added with a Hann window at a fixed 15 ms
//! hop. Speed 1.0 never touches the audio until the first non-1.0 speed.

pub struct Stretcher {
    speed: f64,
    hs: usize,
    n: usize,
    tol: usize,
    win: Vec<f32>,
    input: Vec<[f32; 2]>,
    /// `input` summed to mono, for the similarity search.
    mono: Vec<f32>,
    /// Nominal analysis start of the next frame, in `input` coordinates.
    nominal: f64,
    prev_start: usize,
    acc: Vec<[f32; 2]>,
    first: bool,
    active: bool,
}

impl Stretcher {
    pub fn new(rate: u32) -> Self {
        let hs = (rate as usize * 15) / 1000;
        let n = hs * 2;
        let win = (0..n)
            .map(|i| {
                let s = (std::f32::consts::PI * i as f32 / n as f32).sin();
                s * s
            })
            .collect();
        Self {
            speed: 1.0,
            hs,
            n,
            tol: hs / 2,
            win,
            input: Vec::new(),
            mono: Vec::new(),
            nominal: 0.0,
            prev_start: 0,
            acc: vec![[0.0; 2]; hs],
            first: true,
            active: false,
        }
    }

    pub fn set_speed(&mut self, speed: f64) {
        self.speed = speed.clamp(0.25, 4.0);
    }

    pub fn speed(&self) -> f64 {
        self.speed
    }

    /// Forgets all state (seek / new track).
    pub fn reset(&mut self) {
        self.input.clear();
        self.mono.clear();
        self.nominal = 0.0;
        self.prev_start = 0;
        self.acc.iter_mut().for_each(|f| *f = [0.0; 2]);
        self.first = true;
        self.active = false;
    }

    /// Stretches interleaved stereo `input`, appending to `out`.
    pub fn process(&mut self, input: &[f32], out: &mut Vec<f32>) {
        if !self.active && self.speed == 1.0 {
            out.extend_from_slice(input);
            return;
        }
        self.active = true;
        self.input.extend(input.chunks_exact(2).map(|f| [f[0], f[1]]));
        self.mono.extend(input.chunks_exact(2).map(|f| f[0] + f[1]));
        self.run(out, false);
    }

    /// Emits what is still buffered at the end of a track.
    pub fn finish(&mut self, out: &mut Vec<f32>) {
        if !self.active {
            return;
        }
        let real_end = self.input.len();
        let pad = self.n + self.tol + 2;
        self.input.extend(std::iter::repeat([0.0; 2]).take(pad));
        self.mono.extend(std::iter::repeat(0.0).take(pad));
        self.run(out, true);
        let _ = real_end;
        self.reset();
    }

    fn run(&mut self, out: &mut Vec<f32>, finishing: bool) {
        let (hs, n, tol) = (self.hs, self.n, self.tol);
        let real_end = if finishing { self.input.len() - (n + tol + 2) } else { usize::MAX };
        loop {
            let need = self.nominal.ceil() as usize + tol + n + 1;
            if self.input.len() < need.max(n) {
                break;
            }
            if finishing && self.nominal as usize >= real_end {
                break;
            }
            if self.first {
                for i in 0..hs {
                    out.extend_from_slice(&self.input[i]);
                }
                for i in 0..hs {
                    let w = self.win[hs + i];
                    let s = self.input[hs + i];
                    self.acc[i] = [s[0] * w, s[1] * w];
                }
                self.prev_start = 0;
                self.first = false;
            } else {
                let start = self.best_start();
                for i in 0..hs {
                    let w = self.win[i];
                    let s = self.input[start + i];
                    let a = self.acc[i];
                    out.push(a[0] + s[0] * w);
                    out.push(a[1] + s[1] * w);
                }
                for i in 0..hs {
                    let w = self.win[hs + i];
                    let s = self.input[start + hs + i];
                    self.acc[i] = [s[0] * w, s[1] * w];
                }
                self.prev_start = start;
            }
            self.nominal += hs as f64 * self.speed;

            // Release input that can no longer be referenced.
            let keep_from = self.prev_start;
            if keep_from > 16384 {
                self.input.drain(..keep_from);
                self.mono.drain(..keep_from);
                self.nominal -= keep_from as f64;
                self.prev_start = 0;
            }
        }
    }

    /// The start near `nominal` whose first `hs` frames best continue the
    /// previous frame's natural continuation.
    ///
    /// Two passes on contiguous mono slices (which the compiler vectorizes): a
    /// coarse one over every 4th candidate using half the window, then a fine
    /// one around the winner using the whole window.
    fn best_start(&self) -> usize {
        let hs = self.hs;
        let target = self.nominal.round() as i64;
        let lo = (target - self.tol as i64).max(0) as usize;
        let hi = ((target + self.tol as i64) as usize).min(self.input.len() - self.n);
        if lo >= hi {
            return lo.min(self.input.len() - self.n);
        }
        let template = self.prev_start + hs;
        let score = |start: usize, len: usize| -> f32 {
            let cand = &self.mono[start..start + len];
            let tmpl = &self.mono[template..template + len];
            // Eight independent accumulators: a single running sum is a
            // dependency chain the compiler may not reorder, eight lanes map
            // straight onto SIMD registers.
            let (mut dot, mut energy) = ([0.0f32; 8], [0.0f32; 8]);
            let (cc, tc) = (cand.chunks_exact(8), tmpl.chunks_exact(8));
            let (c_rest, t_rest) = (cc.remainder(), tc.remainder());
            for (c, t) in cc.zip(tc) {
                for k in 0..8 {
                    dot[k] += c[k] * t[k];
                    energy[k] += c[k] * c[k];
                }
            }
            let mut d: f32 = dot.iter().sum();
            let mut e: f32 = energy.iter().sum::<f32>() + 1e-9;
            for (c, t) in c_rest.iter().zip(t_rest) {
                d += c * t;
                e += c * c;
            }
            d / e.sqrt()
        };

        let half = hs / 2;
        let mut best = (lo, f32::MIN);
        for s in (lo..=hi).step_by(4) {
            let sc = score(s, half);
            if sc > best.1 {
                best = (s, sc);
            }
        }
        let (from, to) = (best.0.saturating_sub(3).max(lo), (best.0 + 3).min(hi));
        let mut fine = (best.0, f32::MIN);
        for s in from..=to {
            let sc = score(s, hs);
            if sc > fine.1 {
                fine = (s, sc);
            }
        }
        fine.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sine(freq: f32, rate: u32, secs: f32) -> Vec<f32> {
        let n = (rate as f32 * secs) as usize;
        (0..n)
            .flat_map(|i| {
                let v = (2.0 * std::f32::consts::PI * freq * i as f32 / rate as f32).sin() * 0.5;
                [v, v]
            })
            .collect()
    }

    fn run(speed: f64, input: &[f32], rate: u32) -> Vec<f32> {
        let mut s = Stretcher::new(rate);
        s.set_speed(speed);
        let mut out = Vec::new();
        for chunk in input.chunks(4096) {
            s.process(chunk, &mut out);
        }
        s.finish(&mut out);
        out
    }

    fn frequency(buf: &[f32], rate: u32) -> f32 {
        let mono: Vec<f32> = buf.chunks_exact(2).map(|f| f[0]).collect();
        let skip = rate as usize / 10;
        let seg = &mono[skip..mono.len() - skip];
        let crossings = seg.windows(2).filter(|w| w[0] <= 0.0 && w[1] > 0.0).count();
        crossings as f32 / (seg.len() as f32 / rate as f32)
    }

    fn rms(buf: &[f32]) -> f32 {
        let seg = &buf[buf.len() / 4..buf.len() * 3 / 4];
        (seg.iter().map(|s| s * s).sum::<f32>() / seg.len() as f32).sqrt()
    }

    #[test]
    fn speed_one_is_bit_exact() {
        let input = sine(440.0, 44100, 0.5);
        assert_eq!(run(1.0, &input, 44100), input);
    }

    #[test]
    fn faster_is_shorter_but_keeps_pitch_and_level() {
        let rate = 44100;
        let input = sine(440.0, rate, 3.0);
        for speed in [1.25, 1.5, 2.0] {
            let out = run(speed, &input, rate);
            let ratio = (input.len() as f64 / out.len() as f64).abs();
            assert!((ratio - speed).abs() < 0.04 * speed, "speed {speed}: length ratio {ratio}");
            let f = frequency(&out, rate);
            assert!((f - 440.0).abs() < 8.0, "speed {speed}: pitch {f}");
            let (a, b) = (rms(&input), rms(&out));
            assert!((a / b - 1.0).abs() < 0.12, "speed {speed}: rms {a} vs {b}");
        }
    }

    #[test]
    fn slower_is_longer_but_keeps_pitch() {
        let rate = 44100;
        let input = sine(220.0, rate, 3.0);
        for speed in [0.5, 0.75] {
            let out = run(speed, &input, rate);
            let ratio = input.len() as f64 / out.len() as f64;
            assert!((ratio - speed).abs() < 0.04, "speed {speed}: length ratio {ratio}");
            let f = frequency(&out, rate);
            assert!((f - 220.0).abs() < 6.0, "speed {speed}: pitch {f}");
        }
    }

    #[test]
    fn reset_starts_clean() {
        let rate = 48000;
        let mut s = Stretcher::new(rate);
        s.set_speed(1.5);
        let mut out = Vec::new();
        s.process(&sine(440.0, rate, 1.0), &mut out);
        s.reset();
        out.clear();
        s.process(&sine(440.0, rate, 1.0), &mut out);
        s.finish(&mut out);
        assert!(!out.is_empty());
        assert!(out.iter().all(|v| v.is_finite()));
    }
}

//! Parametric equalizer: cascaded RBJ peaking biquads.
//!
//! The maths is the same as libavfilter's `equalizer` (`t=q`) and the Dart
//! `responseDb` that draws the on-screen curve, so what the user sees is what
//! the engine does.

use std::f64::consts::PI;

/// One peaking filter. `repr(C)`: the Dart side fills an array of these.
#[derive(Clone, Copy, Debug, PartialEq)]
#[repr(C)]
pub struct Band {
    pub freq: f32,
    pub q: f32,
    pub gain_db: f32,
}

#[derive(Clone, Copy, Debug, Default)]
struct Coeffs {
    b0: f64,
    b1: f64,
    b2: f64,
    a1: f64,
    a2: f64,
}

/// RBJ "peakingEQ" coefficients, normalised by `a0`.
fn peaking(fs: f64, f0: f64, q: f64, gain_db: f64) -> Coeffs {
    let a = 10f64.powf(gain_db / 40.0);
    let w0 = 2.0 * PI * f0 / fs;
    let alpha = w0.sin() / (2.0 * q);
    let cos_w0 = w0.cos();
    let a0 = 1.0 + alpha / a;
    Coeffs {
        b0: (1.0 + alpha * a) / a0,
        b1: (-2.0 * cos_w0) / a0,
        b2: (1.0 - alpha * a) / a0,
        a1: (-2.0 * cos_w0) / a0,
        a2: (1.0 - alpha / a) / a0,
    }
}

/// Magnitude response of [`bands`] at `hz`, in dB (sample rate `fs`).
pub fn response_db(bands: &[Band], fs: f64, hz: f64) -> f64 {
    let w = 2.0 * PI * hz / fs;
    let (cos_w, sin_w) = (w.cos(), w.sin());
    let (cos_2w, sin_2w) = ((2.0 * w).cos(), (2.0 * w).sin());
    let mut db = 0.0;
    for b in bands {
        if !usable(b, fs) {
            continue;
        }
        let c = peaking(fs, b.freq as f64, b.q as f64, b.gain_db as f64);
        let num_re = c.b0 + c.b1 * cos_w + c.b2 * cos_2w;
        let num_im = -(c.b1 * sin_w + c.b2 * sin_2w);
        let den_re = 1.0 + c.a1 * cos_w + c.a2 * cos_2w;
        let den_im = -(c.a1 * sin_w + c.a2 * sin_2w);
        let num = num_re * num_re + num_im * num_im;
        let den = den_re * den_re + den_im * den_im;
        db += 10.0 * (num / den).log10();
    }
    db
}

/// Largest positive combined response, in dB (never negative).
pub fn peak_boost_db(bands: &[Band], fs: f64) -> f64 {
    let mut peak = 0.0f64;
    for i in 0..=96 {
        let hz = 20.0 * 1000f64.powf(i as f64 / 96.0);
        peak = peak.max(response_db(bands, fs, hz));
    }
    peak
}

fn usable(b: &Band, fs: f64) -> bool {
    b.gain_db.abs() >= 0.05 && b.q > 0.0 && (b.freq as f64) > 10.0 && (b.freq as f64) < fs * 0.49
}

#[derive(Clone, Copy, Default)]
struct Stage {
    c: Coeffs,
    /// Transposed direct form II state, per channel.
    z: [[f64; 2]; 2],
}

/// Stereo cascade of peaking filters.
pub struct Equalizer {
    fs: f64,
    stages: Vec<Stage>,
}

impl Equalizer {
    pub fn new(fs: f64) -> Self {
        Self { fs, stages: Vec::new() }
    }

    pub fn set_sample_rate(&mut self, fs: f64) {
        self.fs = fs;
    }

    /// Replaces the bands. Filter state is kept for stages that stay, so a
    /// slider drag does not click.
    pub fn set_bands(&mut self, bands: &[Band]) {
        let usable: Vec<&Band> = bands.iter().filter(|b| usable(b, self.fs)).collect();
        self.stages.resize(usable.len(), Stage::default());
        for (stage, b) in self.stages.iter_mut().zip(usable) {
            stage.c = peaking(self.fs, b.freq as f64, b.q as f64, b.gain_db as f64);
        }
    }

    pub fn is_empty(&self) -> bool {
        self.stages.is_empty()
    }

    /// Filters interleaved stereo frames in place.
    pub fn process(&mut self, buf: &mut [f32]) {
        if self.stages.is_empty() {
            return;
        }
        for frame in buf.chunks_exact_mut(2) {
            for (ch, sample) in frame.iter_mut().enumerate() {
                let mut x = *sample as f64;
                for s in self.stages.iter_mut() {
                    let y = s.c.b0 * x + s.z[ch][0];
                    s.z[ch][0] = s.c.b1 * x - s.c.a1 * y + s.z[ch][1];
                    s.z[ch][1] = s.c.b2 * x - s.c.a2 * y;
                    x = y;
                }
                *sample = x as f32;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sine(freq: f64, fs: f64, secs: f64, amp: f64) -> Vec<f32> {
        let n = (fs * secs) as usize;
        let mut out = Vec::with_capacity(n * 2);
        for i in 0..n {
            let v = (amp * (2.0 * PI * freq * i as f64 / fs).sin()) as f32;
            out.push(v);
            out.push(v);
        }
        out
    }

    fn rms_db(buf: &[f32]) -> f64 {
        let tail = &buf[buf.len() / 2..];
        let e: f64 = tail.iter().map(|&s| (s as f64).powi(2)).sum::<f64>() / tail.len() as f64;
        10.0 * e.log10()
    }

    #[test]
    fn single_band_peaks_at_its_gain() {
        let b = [Band { freq: 1000.0, q: 1.41, gain_db: 6.0 }];
        assert!((response_db(&b, 48000.0, 1000.0) - 6.0).abs() < 0.05);
        assert!(response_db(&b, 48000.0, 100.0).abs() < 1.0);
    }

    #[test]
    fn filtering_matches_the_analytic_response() {
        let fs = 48000.0;
        let bands = [
            Band { freq: 62.5, q: 1.41, gain_db: 5.0 },
            Band { freq: 1000.0, q: 1.41, gain_db: -4.0 },
            Band { freq: 8000.0, q: 1.0, gain_db: 3.5 },
        ];
        for &hz in &[50.0, 250.0, 1000.0, 3200.0, 10000.0] {
            let mut eq = Equalizer::new(fs);
            eq.set_bands(&bands);
            let input = sine(hz, fs, 2.0, 0.1);
            let mut out = input.clone();
            eq.process(&mut out);
            let measured = rms_db(&out) - rms_db(&input);
            let expected = response_db(&bands, fs, hz);
            assert!(
                (measured - expected).abs() < 0.05,
                "{hz} Hz: measured {measured:.3}, expected {expected:.3}"
            );
        }
    }

    #[test]
    fn no_bands_is_bit_exact() {
        let mut eq = Equalizer::new(44100.0);
        eq.set_bands(&[]);
        let input = sine(440.0, 44100.0, 0.1, 0.5);
        let mut out = input.clone();
        eq.process(&mut out);
        assert_eq!(input, out);
    }

    #[test]
    fn near_zero_and_invalid_bands_are_skipped() {
        let mut eq = Equalizer::new(48000.0);
        eq.set_bands(&[
            Band { freq: 1000.0, q: 1.0, gain_db: 0.01 },
            Band { freq: 30000.0, q: 1.0, gain_db: 6.0 },
            Band { freq: 1000.0, q: 0.0, gain_db: 6.0 },
        ]);
        assert!(eq.is_empty());
    }

    #[test]
    fn peak_boost_covers_overlapping_bands() {
        let bands = [
            Band { freq: 40.0, q: 0.9, gain_db: 6.0 },
            Band { freq: 70.0, q: 1.0, gain_db: 5.5 },
        ];
        let peak = peak_boost_db(&bands, 48000.0);
        assert!(peak > 6.0 && peak < 12.0, "{peak}");
    }
}

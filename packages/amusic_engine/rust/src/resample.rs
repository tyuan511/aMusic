//! Streaming stereo resampler (4-point cubic Hermite).
//!
//! Good enough for the spike; swap for a windowed-sinc resampler before
//! shipping audiophile playback.

pub struct Resampler {
    step: f64,
    pos: f64,
    buf: Vec<[f32; 2]>,
    passthrough: bool,
}

impl Resampler {
    pub fn new(from: u32, to: u32) -> Self {
        Self {
            step: from as f64 / to as f64,
            // buf[0] is one frame of history; the first real sample is buf[1].
            pos: 1.0,
            buf: vec![[0.0; 2]],
            passthrough: from == to,
        }
    }

    /// Resamples interleaved stereo `input`, appending to `out`.
    pub fn process(&mut self, input: &[f32], out: &mut Vec<f32>) {
        if self.passthrough {
            out.extend_from_slice(input);
            return;
        }
        self.buf.extend(input.chunks_exact(2).map(|f| [f[0], f[1]]));
        // pos indexes `buf`; interpolate between buf[i] and buf[i + 1], with
        // buf[i - 1] and buf[i + 2] as the outer taps.
        while (self.pos as usize) + 2 < self.buf.len() {
            let i = self.pos as usize;
            let t = (self.pos - i as f64) as f32;
            for ch in 0..2 {
                let (y0, y1, y2, y3) = (
                    self.buf[i - 1][ch],
                    self.buf[i][ch],
                    self.buf[i + 1][ch],
                    self.buf[i + 2][ch],
                );
                out.push(hermite(y0, y1, y2, y3, t));
            }
            self.pos += self.step;
        }
        // Drop what can no longer be referenced (keep one frame of history).
        let keep_from = (self.pos as usize).saturating_sub(1);
        if keep_from > 4096 {
            self.buf.drain(..keep_from);
            self.pos -= keep_from as f64;
        }
    }
}

fn hermite(y0: f32, y1: f32, y2: f32, y3: f32, t: f32) -> f32 {
    let c0 = y1;
    let c1 = 0.5 * (y2 - y0);
    let c2 = y0 - 2.5 * y1 + 2.0 * y2 - 0.5 * y3;
    let c3 = 0.5 * (y3 - y0) + 1.5 * (y1 - y2);
    ((c3 * t + c2) * t + c1) * t + c0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn upsampling_keeps_a_sine_and_scales_the_length() {
        let (from, to) = (44100u32, 48000u32);
        let n = from as usize;
        let input: Vec<f32> = (0..n)
            .flat_map(|i| {
                let v = (2.0 * std::f32::consts::PI * 1000.0 * i as f32 / from as f32).sin() * 0.5;
                [v, v]
            })
            .collect();
        let mut r = Resampler::new(from, to);
        let mut out = Vec::new();
        for chunk in input.chunks(2048) {
            r.process(chunk, &mut out);
        }
        let frames = out.len() / 2;
        assert!((frames as i64 - to as i64).abs() < 8, "frames {frames}");
        // The resampled sine must still be a 1 kHz sine at 48 kHz.
        let mut worst = 0.0f32;
        for i in 16..frames - 16 {
            let want = (2.0 * std::f32::consts::PI * 1000.0 * i as f32 / to as f32).sin() * 0.5;
            let got = out[i * 2];
            worst = worst.max((got - want).abs());
        }
        assert!(worst < 0.02, "worst error {worst}");
    }

    #[test]
    fn same_rate_is_passthrough() {
        let mut r = Resampler::new(48000, 48000);
        let mut out = Vec::new();
        r.process(&[0.1, 0.2, 0.3, 0.4], &mut out);
        assert_eq!(out, vec![0.1, 0.2, 0.3, 0.4]);
    }
}

//! Look-ahead brick-wall limiter (min filter + moving average).
//!
//! Every output sample is multiplied by a gain that is at most
//! `ceiling / |peak|` for that very sample, so the output never exceeds the
//! ceiling, while the gain moves smoothly over the look-ahead window instead of
//! clipping. This is what lets the equalizer boost without turning the whole
//! track down.

use std::collections::VecDeque;

pub struct Limiter {
    ceiling: f32,
    look: usize,
    delay: Vec<[f32; 2]>,
    delay_idx: usize,
    min_window: VecDeque<(u64, f32)>,
    count: u64,
    avg: Vec<f32>,
    avg_idx: usize,
    avg_sum: f64,
}

impl Limiter {
    /// `look` is the look-ahead in frames (about 3 ms is plenty).
    pub fn new(ceiling: f32, look: usize) -> Self {
        let look = look.max(2);
        Self {
            ceiling,
            look,
            delay: vec![[0.0; 2]; look - 1],
            delay_idx: 0,
            min_window: VecDeque::new(),
            count: 0,
            avg: vec![1.0; look],
            avg_idx: 0,
            avg_sum: look as f64,
        }
    }

    /// Output delay in frames.
    pub fn latency(&self) -> usize {
        self.look - 1
    }

    pub fn process(&mut self, buf: &mut [f32]) {
        for frame in buf.chunks_exact_mut(2) {
            let (l, r) = (frame[0], frame[1]);
            let peak = l.abs().max(r.abs());
            let need = if peak > self.ceiling {
                self.ceiling / peak
            } else {
                1.0
            };

            while self.min_window.back().is_some_and(|&(_, v)| v >= need) {
                self.min_window.pop_back();
            }
            self.min_window.push_back((self.count, need));
            while self
                .min_window
                .front()
                .is_some_and(|&(i, _)| i + self.look as u64 <= self.count)
            {
                self.min_window.pop_front();
            }
            let min = self.min_window.front().map_or(1.0, |&(_, v)| v);
            self.count += 1;

            self.avg_sum += (min - self.avg[self.avg_idx]) as f64;
            self.avg[self.avg_idx] = min;
            self.avg_idx = (self.avg_idx + 1) % self.look;
            let gain = (self.avg_sum / self.look as f64) as f32;

            let delayed = self.delay[self.delay_idx];
            self.delay[self.delay_idx] = [l, r];
            self.delay_idx = (self.delay_idx + 1) % self.delay.len();

            frame[0] = delayed[0] * gain;
            frame[1] = delayed[1] * gain;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn never_exceeds_the_ceiling() {
        let mut lim = Limiter::new(0.97, 144);
        let mut buf: Vec<f32> = (0..48000 * 2)
            .map(|i| {
                let t = (i / 2) as f32 / 48000.0;
                3.0 * (2.0 * std::f32::consts::PI * 60.0 * t).sin()
            })
            .collect();
        lim.process(&mut buf);
        let max = buf.iter().fold(0.0f32, |m, &s| m.max(s.abs()));
        assert!(max <= 0.9701, "max {max}");
        assert!(max > 0.9, "limiter should not crush the signal, max {max}");
    }

    #[test]
    fn quiet_signal_passes_through_delayed_and_unchanged() {
        let mut lim = Limiter::new(0.97, 100);
        let input: Vec<f32> = (0..2000)
            .map(|i| ((i / 2) as f32 * 0.01).sin() * 0.3)
            .collect();
        let mut out = input.clone();
        lim.process(&mut out);
        let d = lim.latency() * 2;
        assert_eq!(&out[d..], &input[..input.len() - d]);
    }
}

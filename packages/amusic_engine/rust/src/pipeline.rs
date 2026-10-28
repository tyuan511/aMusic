//! The processing chain between decoder and output: equalizer, sound effect,
//! software gain, limiter. Everything runs on interleaved stereo `f32`.

use crate::dsp::{Band, Equalizer};
use crate::effects::{Effect, EffectChain};
use crate::limiter::Limiter;

/// What the UI asks for.
#[derive(Clone, Debug, PartialEq)]
pub struct EqConfig {
    pub bands: Vec<Band>,
    /// Software gain in dB (preamp). With the limiter on there is no need for
    /// the "headroom" the mpv build had to reserve.
    pub gain_db: f32,
    pub limiter: bool,
    /// A DSP sound effect (spatial, reverb, exciter). The app never combines
    /// it with the equalizer, but the chain would run both in that order.
    pub effect: Effect,
}

impl Default for EqConfig {
    fn default() -> Self {
        Self {
            bands: Vec::new(),
            gain_db: 0.0,
            limiter: true,
            effect: Effect::None,
        }
    }
}

pub struct Pipeline {
    fs: u32,
    eq: Equalizer,
    fx: EffectChain,
    limiter: Limiter,
    limiter_on: bool,
    gain: f32,
    gain_target: f32,
    gain_step: f32,
}

const CEILING: f32 = 0.98;

impl Pipeline {
    pub fn new(fs: u32) -> Self {
        Self {
            fs,
            eq: Equalizer::new(fs as f64),
            fx: EffectChain::new(fs),
            limiter: Limiter::new(CEILING, (fs as usize * 3) / 1000),
            limiter_on: true,
            gain: 1.0,
            gain_target: 1.0,
            // 20 ms ramp keeps gain changes click free.
            gain_step: 1.0 / (fs as f32 * 0.02),
        }
    }

    pub fn set_config(&mut self, cfg: &EqConfig) {
        self.eq.set_bands(&cfg.bands);
        self.fx.set_effect(cfg.effect);
        self.gain_target = 10f32.powf(cfg.gain_db / 20.0);
        self.limiter_on = cfg.limiter;
    }

    pub fn sample_rate(&self) -> u32 {
        self.fs
    }

    /// Frames of delay the chain adds.
    pub fn latency(&self) -> usize {
        if self.limiter_on {
            self.limiter.latency()
        } else {
            0
        }
    }

    pub fn process(&mut self, buf: &mut [f32]) {
        self.eq.process(buf);
        self.fx.process(buf);
        if self.gain != self.gain_target {
            for frame in buf.chunks_exact_mut(2) {
                let step = self.gain_step * self.gain_target.max(1.0);
                let d = self.gain_target - self.gain;
                self.gain += d.clamp(-step, step);
                frame[0] *= self.gain;
                frame[1] *= self.gain;
            }
        } else if self.gain != 1.0 {
            for s in buf.iter_mut() {
                *s *= self.gain;
            }
        }
        if self.limiter_on {
            self.limiter.process(buf);
        }
    }

    /// Pushes silence through so the limiter's delayed tail comes out.
    pub fn flush(&mut self, out: &mut Vec<f32>) {
        if !self.limiter_on {
            return;
        }
        let mut tail = vec![0.0f32; self.limiter.latency() * 2];
        self.limiter.process(&mut tail);
        out.extend_from_slice(&tail);
    }
}

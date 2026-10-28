//! Integrated loudness (EBU R128) of a local file, for volume normalisation.

use std::path::Path;

use ebur128::{EbuR128, Mode};

use crate::decode::Decoder;

/// Longest stretch analysed, in seconds; anything longer is judged by its start.
const MAX_SECONDS: f64 = 20.0 * 60.0;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Loudness {
    /// Integrated loudness in LUFS.
    pub lufs: f64,
    /// Highest sample magnitude (linear, 1.0 = full scale).
    pub peak: f64,
}

/// Decodes `path` and measures it. `None` when it cannot be read or is silent.
pub fn analyze(path: &Path) -> Option<Loudness> {
    let mut decoder = Decoder::open(path).ok()?;
    let rate = decoder.sample_rate;
    let mut meter = EbuR128::new(2, rate, Mode::I | Mode::SAMPLE_PEAK).ok()?;
    let mut frames = Vec::new();
    let mut total = 0usize;
    let limit = (MAX_SECONDS * f64::from(rate)) as usize;
    while total < limit {
        frames.clear();
        match decoder.next_frames(&mut frames) {
            Ok(true) => {}
            _ => break,
        }
        if frames.is_empty() {
            continue;
        }
        total += frames.len() / 2;
        meter.add_frames_f32(&frames).ok()?;
    }
    let lufs = meter.loudness_global().ok()?;
    if !lufs.is_finite() {
        return None;
    }
    let peak = (0..2)
        .filter_map(|c| meter.sample_peak(c).ok())
        .fold(0.0, f64::max);
    Some(Loudness { lufs, peak })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn wav(path: &Path, amplitude: f32) {
        let rate = 44100u32;
        let n = rate * 3;
        let mut data = Vec::new();
        for i in 0..n {
            let s = (i as f32 * 440.0 * std::f32::consts::TAU / rate as f32).sin() * amplitude;
            let v = (s * 32767.0) as i16;
            data.extend_from_slice(&v.to_le_bytes());
            data.extend_from_slice(&v.to_le_bytes());
        }
        let mut f = std::fs::File::create(path).unwrap();
        f.write_all(b"RIFF").unwrap();
        f.write_all(&(36 + data.len() as u32).to_le_bytes())
            .unwrap();
        f.write_all(b"WAVEfmt ").unwrap();
        f.write_all(&16u32.to_le_bytes()).unwrap();
        for v in [1u16, 2] {
            f.write_all(&v.to_le_bytes()).unwrap();
        }
        f.write_all(&rate.to_le_bytes()).unwrap();
        f.write_all(&(rate * 4).to_le_bytes()).unwrap();
        f.write_all(&4u16.to_le_bytes()).unwrap();
        f.write_all(&16u16.to_le_bytes()).unwrap();
        f.write_all(b"data").unwrap();
        f.write_all(&(data.len() as u32).to_le_bytes()).unwrap();
        f.write_all(&data).unwrap();
    }

    #[test]
    fn louder_files_measure_louder() {
        let dir = std::env::temp_dir();
        let (quiet, loud) = (dir.join("amusic_q.wav"), dir.join("amusic_l.wav"));
        wav(&quiet, 0.1);
        wav(&loud, 0.5);
        let q = analyze(&quiet).unwrap();
        let l = analyze(&loud).unwrap();
        // 0.5 / 0.1 = +13.98 dB.
        assert!((l.lufs - q.lufs - 13.98).abs() < 0.3, "{q:?} {l:?}");
        assert!((l.peak - 0.5).abs() < 0.01);
        // A -3 dBFS stereo sine reads about -6 LUFS-ish; sanity bound only.
        assert!(l.lufs < 0.0 && l.lufs > -30.0);
        let _ = (std::fs::remove_file(quiet), std::fs::remove_file(loud));
    }

    #[test]
    fn unreadable_is_none() {
        assert!(analyze(Path::new("/no/such/file.flac")).is_none());
    }
}

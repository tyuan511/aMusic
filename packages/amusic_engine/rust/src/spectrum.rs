//! Offline spectrum/envelope analysis for the full-screen seek bar.
//!
//! The decoder runs outside Flutter's UI isolate. Each short FFT window is
//! reduced to a loudness/brightness value, then resampled over the track's
//! timeline. The result is a compact, smooth byte envelope for painting.

use crate::decode::Decoder;

const FFT_SIZE: usize = 1024;

/// Returns one normalised magnitude byte for each timeline segment.
pub fn analyze(location: &str, segments: usize) -> Option<Vec<u8>> {
    if segments == 0 {
        return Some(Vec::new());
    }
    let mut decoder = Decoder::open_any(location).ok()?;
    let sample_rate = decoder.sample_rate as f64;
    let mut real = vec![0.0f64; FFT_SIZE];
    let mut imag = vec![0.0f64; FFT_SIZE];
    let mut mono = Vec::with_capacity(FFT_SIZE * 2);
    let mut analysed = 0usize;
    let mut packet = Vec::new();
    let mut energies = Vec::new();

    loop {
        packet.clear();
        match decoder.next_frames(&mut packet) {
            Ok(true) => {
                for frame in packet.chunks_exact(2) {
                    mono.push((frame[0] + frame[1]) as f64 * 0.5);
                }
            }
            Ok(false) => break,
            Err(_) => return None,
        }
        while mono.len().saturating_sub(analysed) >= FFT_SIZE {
            energies.push(analyse_window(
                &mono[analysed..analysed + FFT_SIZE],
                sample_rate,
                &mut real,
                &mut imag,
            ));
            analysed += FFT_SIZE;
        }
        // Avoid shifting the whole decoded track for every FFT window. Keep
        // a modest tail for the next packet, then discard the consumed prefix
        // in one operation.
        if analysed >= 64 * FFT_SIZE {
            mono.drain(..analysed);
            analysed = 0;
        }
    }
    if analysed < mono.len() {
        let mut padded = vec![0.0; FFT_SIZE];
        let rest = &mono[analysed..];
        padded[..rest.len()].copy_from_slice(rest);
        energies.push(analyse_window(&padded, sample_rate, &mut real, &mut imag));
    }
    if energies.is_empty() {
        return Some(vec![0; segments]);
    }

    // Resample the short-window values over time. Taking more of the peak
    // keeps drums and consonants visible while the mean keeps the line smooth.
    let mut values = Vec::with_capacity(segments);
    for segment in 0..segments {
        let start = segment * energies.len() / segments;
        let end = ((segment + 1) * energies.len() / segments).max(start + 1);
        let slice = &energies[start.min(energies.len() - 1)..end.min(energies.len())];
        let mean = slice.iter().sum::<f64>() / slice.len() as f64;
        let peak = slice.iter().copied().fold(0.0, f64::max);
        values.push(mean * 0.38 + peak * 0.52);
    }

    // Stretch between low and high quantiles instead of dividing by a single
    // peak. Loud masters often have a narrow RMS range; peak-only
    // normalisation would turn almost every segment into the same height.
    let mut sorted = values.clone();
    sorted.sort_by(f64::total_cmp);
    let low = sorted[((sorted.len() as f64 * 0.22) as usize).min(sorted.len() - 1)];
    let high = sorted[((sorted.len() as f64 * 0.78) as usize).min(sorted.len() - 1)];
    let spread = (high - low).max(f64::EPSILON);
    let global = values
        .iter()
        .copied()
        .into_iter()
        .map(|value| {
            let loudness = ((value - low) / spread).clamp(0.0, 1.0).powf(0.82);
            loudness
        })
        .collect::<Vec<_>>();

    // Give each neighbourhood its own contrast window. This keeps a quiet
    // verse from becoming a long flat strip just because the chorus is louder
    // elsewhere in the track, while the global component preserves the song's
    // broad dynamics.
    let radius = 6usize;
    let mut normalised = Vec::with_capacity(values.len());
    for (index, &value) in values.iter().enumerate() {
        let start = index.saturating_sub(radius);
        let end = (index + radius + 1).min(values.len());
        let mut neighbourhood = values[start..end].to_vec();
        neighbourhood.sort_by(f64::total_cmp);
        let local_low = neighbourhood
            [((neighbourhood.len() as f64 * 0.18) as usize).min(neighbourhood.len() - 1)];
        let local_high = neighbourhood
            [((neighbourhood.len() as f64 * 0.82) as usize).min(neighbourhood.len() - 1)];
        let local_spread = (local_high - local_low).max(f64::EPSILON);
        let local = ((value - local_low) / local_spread).clamp(0.0, 1.0);
        let contrast = (local * 0.72 + global[index] * 0.28).powf(0.78);
        normalised.push(0.08 + contrast * 0.92);
    }
    // A three-point pass removes packet/window boundaries without making the
    // progress shape lag behind the actual music.
    if normalised.len() > 2 {
        let original = normalised.clone();
        for i in 1..normalised.len() - 1 {
            normalised[i] = original[i - 1] * 0.2 + original[i] * 0.6 + original[i + 1] * 0.2;
        }
    }
    Some(
        normalised
            .into_iter()
            .map(|value| (value.clamp(0.0, 1.0) * 255.0).round() as u8)
            .collect(),
    )
}

fn analyse_window(samples: &[f64], sample_rate: f64, real: &mut [f64], imag: &mut [f64]) -> f64 {
    real.fill(0.0);
    imag.fill(0.0);
    let mut sum = 0.0;
    let mut peak = 0.0f64;
    for (i, &sample) in samples.iter().enumerate().take(FFT_SIZE) {
        let window = 0.5 - 0.5 * (std::f64::consts::TAU * i as f64 / (FFT_SIZE - 1) as f64).cos();
        real[i] = sample * window;
        sum += sample * sample;
        peak = peak.max(sample.abs());
    }
    fft(real, imag);

    // Mix broadband loudness with a small high-frequency contribution. This
    // keeps instrumental detail from disappearing when vocals drop out.
    let mut total = 0.0;
    let mut bright = 0.0;
    for k in 1..(FFT_SIZE / 2) {
        let power = real[k] * real[k] + imag[k] * imag[k];
        let frequency = k as f64 * sample_rate / FFT_SIZE as f64;
        total += power;
        if frequency > 1800.0 {
            bright += power;
        }
    }
    let brightness = if total > f64::EPSILON {
        (bright / total).sqrt().clamp(0.0, 1.0)
    } else {
        0.0
    };
    let rms = (sum / samples.len().max(1) as f64).sqrt();
    (rms * 0.48 + peak * 0.38) * (0.72 + brightness * 0.28)
}

fn fft(real: &mut [f64], imag: &mut [f64]) {
    let n = real.len();
    let mut j = 0usize;
    for i in 1..n {
        let mut bit = n >> 1;
        while j & bit != 0 {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;
        if i < j {
            real.swap(i, j);
            imag.swap(i, j);
        }
    }

    let mut length = 2;
    while length <= n {
        let angle = -std::f64::consts::TAU / length as f64;
        let w_len_real = angle.cos();
        let w_len_imag = angle.sin();
        for start in (0..n).step_by(length) {
            let mut w_real = 1.0;
            let mut w_imag = 0.0;
            for i in 0..length / 2 {
                let even = start + i;
                let odd = even + length / 2;
                let odd_real = real[odd] * w_real - imag[odd] * w_imag;
                let odd_imag = real[odd] * w_imag + imag[odd] * w_real;
                real[odd] = real[even] - odd_real;
                imag[odd] = imag[even] - odd_imag;
                real[even] += odd_real;
                imag[even] += odd_imag;
                let next_real = w_real * w_len_real - w_imag * w_len_imag;
                w_imag = w_real * w_len_imag + w_imag * w_len_real;
                w_real = next_real;
            }
        }
        length <<= 1;
    }
}

#[cfg(test)]
mod tests {
    use super::fft;

    #[test]
    fn fft_detects_a_single_bin() {
        let n = 16;
        let mut real = (0..n)
            .map(|i| (std::f64::consts::TAU * 2.0 * i as f64 / n as f64).cos())
            .collect::<Vec<_>>();
        let mut imag = vec![0.0; n];
        fft(&mut real, &mut imag);
        let strongest = (1..n / 2)
            .max_by(|&a, &b| {
                (real[a] * real[a] + imag[a] * imag[a])
                    .partial_cmp(&(real[b] * real[b] + imag[b] * imag[b]))
                    .unwrap()
            })
            .unwrap();
        assert_eq!(strongest, 2);
    }
}

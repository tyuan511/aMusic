//! CPU cost of each engine stage, as a percentage of one core needed to play
//! in real time (lower is better).
//!
//!   cargo run --release --example bench -- music.mp3 music.m4a music.flac

use std::path::Path;
use std::time::Instant;

use amusic_engine::decode::Decoder;
use amusic_engine::resample::Resampler;
use amusic_engine::stretch::Stretcher;
use amusic_engine::{Band, Effect, EqConfig, Pipeline};

fn percent_of_core(work: std::time::Duration, audio_secs: f64) -> f64 {
    work.as_secs_f64() / audio_secs * 100.0
}

fn noise(frames: usize) -> Vec<f32> {
    let mut s = 0x2545F491u32;
    (0..frames * 2)
        .map(|_| {
            s = s.wrapping_mul(1664525).wrapping_add(1013904223);
            ((s >> 8) as f32 / 8388608.0 - 1.0) * 0.3
        })
        .collect()
}

fn bench_pipeline(name: &str, cfg: &EqConfig, rate: u32) {
    let audio_secs = 20.0;
    let mut p = Pipeline::new(rate);
    p.set_config(cfg);
    let mut buf = noise((rate as f64 * audio_secs) as usize);
    // The audio callback hands over ~10 ms at a time.
    let chunk = (rate as usize / 100) * 2;
    let start = Instant::now();
    for c in buf.chunks_mut(chunk) {
        p.process(c);
    }
    println!(
        "  {name:<24} {:>6.2} %",
        percent_of_core(start.elapsed(), audio_secs)
    );
}

fn main() {
    let files: Vec<String> = std::env::args().skip(1).collect();
    let rate = 48000;

    println!("DSP at {rate} Hz stereo (percent of one core):");
    let ten_bands: Vec<Band> = [
        31.25, 62.5, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
    ]
    .iter()
    .map(|&f| Band {
        freq: f,
        q: 1.41,
        gain_db: 3.0,
    })
    .collect();
    bench_pipeline("passthrough + limiter", &EqConfig::default(), rate);
    bench_pipeline(
        "limiter off",
        &EqConfig {
            limiter: false,
            ..Default::default()
        },
        rate,
    );
    bench_pipeline(
        "EQ 10 bands",
        &EqConfig {
            bands: ten_bands,
            ..Default::default()
        },
        rate,
    );
    for (name, e) in [
        ("3D surround", Effect::Surround3d),
        ("360 rotate", Effect::Rotate360),
        ("LiveHouse", Effect::LiveHouse),
        ("exciter", Effect::Exciter),
        ("chorus", Effect::Chorus),
        ("echo", Effect::Echo),
        ("dream", Effect::Dream),
    ] {
        bench_pipeline(
            name,
            &EqConfig {
                effect: e,
                ..Default::default()
            },
            rate,
        );
    }

    println!("resample / stretch (percent of one core):");
    let frames = rate as usize * 20;
    let input = noise(frames);
    for (from, to) in [(44100u32, 48000u32), (48000, 44100), (96000, 48000)] {
        let mut r = Resampler::new(from, to);
        let mut out = Vec::new();
        let secs = frames as f64 / from as f64;
        let start = Instant::now();
        for c in input.chunks(8192) {
            r.process(c, &mut out);
        }
        println!(
            "  resample {from}->{to:<8} {:>6.2} %",
            percent_of_core(start.elapsed(), secs)
        );
    }
    for speed in [0.75, 1.25, 2.0] {
        let mut s = Stretcher::new(rate);
        s.set_speed(speed);
        let mut out = Vec::new();
        let secs = frames as f64 / rate as f64;
        let start = Instant::now();
        for c in input.chunks(4096) {
            s.process(c, &mut out);
        }
        println!(
            "  stretch x{speed:<14} {:>6.2} %",
            percent_of_core(start.elapsed(), secs)
        );
    }

    println!("decode (percent of one core):");
    for f in &files {
        let mut d = Decoder::open(Path::new(f)).expect("open");
        let mut out = Vec::new();
        let start = Instant::now();
        let mut frames = 0usize;
        while d.next_frames(&mut out).expect("decode") {
            frames += out.len() / 2;
            out.clear();
        }
        let secs = frames as f64 / d.sample_rate as f64;
        println!(
            "  {:<24} {:>6.2} %  ({} Hz, {:.0}s)",
            Path::new(f).file_name().unwrap().to_string_lossy(),
            percent_of_core(start.elapsed(), secs),
            d.sample_rate,
            secs
        );
    }
}

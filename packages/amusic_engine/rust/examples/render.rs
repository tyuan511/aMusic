//! Offline render: decode a file, run it through the pipeline, write a WAV.
//!
//!   cargo run --release --example render -- in.flac out.wav \
//!       --band 62.5:1.41:5 --band 1000:1.41:-4 --gain -2 [--effect 1..4] [--no-limiter] [--rate 48000]

use std::path::Path;

use amusic_engine::decode::Decoder;
use amusic_engine::resample::Resampler;
use amusic_engine::{Band, Effect, EqConfig, Pipeline};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() < 2 {
        eprintln!(
            "usage: render <in> <out.wav> [--band f:q:g]... [--gain db] [--no-limiter] [--rate hz]"
        );
        std::process::exit(2);
    }
    let (input, output) = (&args[0], &args[1]);
    let mut cfg = EqConfig::default();
    let mut rate: Option<u32> = None;
    let mut i = 2;
    while i < args.len() {
        match args[i].as_str() {
            "--band" => {
                let p: Vec<f32> = args[i + 1].split(':').map(|v| v.parse().unwrap()).collect();
                cfg.bands.push(Band {
                    freq: p[0],
                    q: p[1],
                    gain_db: p[2],
                });
                i += 1;
            }
            "--gain" => {
                cfg.gain_db = args[i + 1].parse().unwrap();
                i += 1;
            }
            "--rate" => {
                rate = Some(args[i + 1].parse().unwrap());
                i += 1;
            }
            "--effect" => {
                cfg.effect = Effect::from_u32(args[i + 1].parse().unwrap());
                i += 1;
            }
            "--no-limiter" => cfg.limiter = false,
            other => panic!("unknown flag {other}"),
        }
        i += 1;
    }

    let mut dec = Decoder::open(Path::new(input)).expect("open");
    let out_rate = rate.unwrap_or(dec.sample_rate);
    eprintln!(
        "decoded {} Hz, duration {:?}, writing {} Hz",
        dec.sample_rate, dec.duration, out_rate
    );
    let mut resampler = Resampler::new(dec.sample_rate, out_rate);
    let mut pipeline = Pipeline::new(out_rate);
    pipeline.set_config(&cfg);

    let spec = hound::WavSpec {
        channels: 2,
        sample_rate: out_rate,
        bits_per_sample: 32,
        sample_format: hound::SampleFormat::Float,
    };
    let mut wav = hound::WavWriter::create(output, spec).expect("create wav");
    let (mut raw, mut rs, mut frames) = (Vec::new(), Vec::new(), 0u64);
    while dec.next_frames(&mut raw).expect("decode") {
        rs.clear();
        resampler.process(&raw, &mut rs);
        raw.clear();
        pipeline.process(&mut rs);
        frames += (rs.len() / 2) as u64;
        for s in &rs {
            wav.write_sample(*s).unwrap();
        }
    }
    let mut tail = Vec::new();
    pipeline.flush(&mut tail);
    for s in &tail {
        wav.write_sample(*s).unwrap();
    }
    wav.finalize().unwrap();
    eprintln!(
        "wrote {frames} frames ({:.2}s)",
        frames as f64 / out_rate as f64
    );
}

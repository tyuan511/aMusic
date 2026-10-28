//! Real-device CPU cost of the whole engine (decode thread, audio callback,
//! cpal) in the states a user spends time in. Volume is 0.
//!
//!   cargo run --release --example cpu -- music.mp3 [effect 0..4] [speed]

use std::thread::sleep;
use std::time::{Duration, Instant};

use amusic_engine::{Band, Effect, EqConfig, Player};

fn usage() -> (f64, i64, i64) {
    let mut ru: libc::rusage = unsafe { std::mem::zeroed() };
    unsafe { libc::getrusage(libc::RUSAGE_SELF, &mut ru) };
    let secs = |t: libc::timeval| t.tv_sec as f64 + t.tv_usec as f64 / 1e6;
    (
        secs(ru.ru_utime) + secs(ru.ru_stime),
        ru.ru_nvcsw,
        ru.ru_nivcsw,
    )
}

fn measure(label: &str, secs: f64) {
    let (cpu0, v0, i0) = usage();
    let start = Instant::now();
    sleep(Duration::from_secs_f64(secs));
    let wall = start.elapsed().as_secs_f64();
    let (cpu1, v1, i1) = usage();
    println!(
        "  {label:<22} cpu {:>5.2} %   wakeups {:>6.0}/s   preemptions {:>4.0}/s",
        (cpu1 - cpu0) / wall * 100.0,
        (v1 - v0) as f64 / wall,
        (i1 - i0) as f64 / wall
    );
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let file = &args[1];
    let effect = args.get(2).and_then(|v| v.parse().ok()).unwrap_or(0u32);
    let speed: f64 = args.get(3).and_then(|v| v.parse().ok()).unwrap_or(1.0);

    let player = Player::new().expect("open output");
    player.set_volume(0.0);
    player.set_speed(speed);
    println!(
        "device {} Hz, effect {effect}, speed {speed}",
        player.sample_rate()
    );
    if effect == 99 {
        let bands = [62.5, 250.0, 1000.0, 4000.0, 16000.0]
            .iter()
            .map(|&f| Band {
                freq: f,
                q: 1.41,
                gain_db: 3.0,
            })
            .collect();
        player.set_eq(EqConfig {
            bands,
            ..Default::default()
        });
    } else {
        player.set_eq(EqConfig {
            effect: Effect::from_u32(effect),
            ..Default::default()
        });
    }

    measure("idle, no track", 4.0);
    player.load(file, 0.0);
    player.wait_loaded(Duration::from_secs(10)).expect("load");
    measure("loaded, paused", 4.0);
    player.play();
    sleep(Duration::from_millis(500));
    measure("playing", 8.0);
    player.pause();
    // Let the output stream go to sleep (it does so after 3 s).
    sleep(Duration::from_secs(4));
    measure("paused, stream asleep", 6.0);
}

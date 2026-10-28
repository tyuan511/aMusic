//! Silent end-to-end check on the real output device (volume 0).
//!
//!   cargo run --release --example smoke -- a.m4a b.mp3
//!
//! Serves both files over a local Range-capable HTTP server and plays them
//! through the engine like the Flutter app does: HTTP streaming, seek,
//! gapless advance to a queued track, 2x speed.

use std::io::{Read, Write};
use std::net::TcpListener;
use std::path::PathBuf;
use std::thread::{self, sleep};
use std::time::{Duration, Instant};

use amusic_engine::player::{STATE_ENDED, STATE_READY};
use amusic_engine::{Band, EqConfig, Player};

fn serve(dir: PathBuf) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    thread::spawn(move || {
        for stream in listener.incoming() {
            let Ok(mut stream) = stream else { continue };
            let dir = dir.clone();
            thread::spawn(move || {
                let mut buf = [0u8; 4096];
                let n = stream.read(&mut buf).unwrap_or(0);
                let req = String::from_utf8_lossy(&buf[..n]).to_string();
                let path = req
                    .split_whitespace()
                    .nth(1)
                    .unwrap_or("/")
                    .trim_start_matches('/')
                    .to_string();
                let Ok(data) = std::fs::read(dir.join(&path)) else {
                    let _ = stream.write_all(
                        b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
                    );
                    return;
                };
                let start = req
                    .lines()
                    .find_map(|l| {
                        l.to_ascii_lowercase()
                            .strip_prefix("range: bytes=")
                            .map(str::to_owned)
                    })
                    .and_then(|r| {
                        r.trim_end_matches('-')
                            .split('-')
                            .next()
                            .and_then(|s| s.parse::<usize>().ok())
                    })
                    .unwrap_or(0)
                    .min(data.len());
                let head = format!(
                    "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes {start}-{}/{}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    data.len().saturating_sub(1),
                    data.len(),
                    data.len() - start
                );
                let _ = stream.write_all(head.as_bytes());
                let _ = stream.write_all(&data[start..]);
            });
        }
    });
    format!("http://{addr}")
}

fn wait(what: &str, timeout: Duration, mut cond: impl FnMut() -> bool) -> Duration {
    let start = Instant::now();
    while !cond() {
        assert!(start.elapsed() < timeout, "timed out waiting for {what}");
        sleep(Duration::from_millis(5));
    }
    start.elapsed()
}

fn main() {
    let args: Vec<PathBuf> = std::env::args().skip(1).map(PathBuf::from).collect();
    assert!(args.len() >= 2, "usage: smoke <a> <b>");
    let (a, b) = (&args[0], &args[1]);
    let base = serve(a.parent().unwrap().to_path_buf());
    let url = |p: &PathBuf| format!("{base}/{}", p.file_name().unwrap().to_string_lossy());

    let player = Player::new().expect("open output");
    println!("device rate {} Hz", player.sample_rate());
    player.set_volume(0.0);

    // 1. HTTP streaming load.
    player.load(&url(a), 0.0);
    player
        .wait_loaded(Duration::from_secs(10))
        .expect("http load");
    let dur_a = player.status().duration;
    println!("streamed {} over http, duration {dur_a:.2}s", a.display());
    assert!(dur_a > 0.0);

    // 2. A missing file reports an error instead of hanging.
    player.load(&format!("{base}/missing.m4a"), 0.0);
    let err = player
        .wait_loaded(Duration::from_secs(10))
        .expect_err("404 must fail");
    println!("404 -> error: {err}");
    player.load(&url(a), 0.0);
    player.wait_loaded(Duration::from_secs(10)).unwrap();

    // 3. Play + live EQ, then a seek.
    player.play();
    sleep(Duration::from_millis(500));
    let pos = player.status().position;
    println!("after 0.5s: {pos:.3}s");
    assert!((0.35..0.7).contains(&pos), "position {pos}");
    player.set_eq(EqConfig {
        bands: vec![Band {
            freq: 62.5,
            q: 1.41,
            gain_db: 6.0,
        }],
        gain_db: 0.0,
        limiter: true,
        ..Default::default()
    });
    player.seek(dur_a * 0.5);
    sleep(Duration::from_millis(200));
    let pos = player.status().position;
    println!("seek to {:.2}s -> {pos:.3}s", dur_a * 0.5);
    assert!((pos - dur_a * 0.5).abs() < 0.4, "seek landed at {pos}");

    // 4. Gapless: queue b, the first track's end rolls into it.
    player.set_next(Some(&url(b)));
    let before = player.status().advance_seq;
    wait("gapless advance", Duration::from_secs(5), || {
        player.status().advance_seq > before
    });
    let st = player.status();
    println!(
        "advanced to next track: position {:.3}s, duration {:.2}s",
        st.position, st.duration
    );
    assert_eq!(st.state, STATE_READY, "must not end between tracks");
    assert!(
        st.position < 0.5,
        "new track should be near its start, got {}",
        st.position
    );
    let dur_b = st.duration;
    wait("end of queue", Duration::from_secs(8), || {
        player.status().state == STATE_ENDED
    });
    println!("queue ended (second track {dur_b:.2}s)");

    // 5. Speed: 2x plays the same audio in half the time.
    player.set_speed(2.0);
    player.load(&url(a), 0.0);
    player.wait_loaded(Duration::from_secs(10)).unwrap();
    player.play();
    let took = wait("2x playback end", Duration::from_secs(6), || {
        player.status().state == STATE_ENDED
    });
    println!("2x: {dur_a:.2}s of audio took {:.2}s", took.as_secs_f64());
    assert!(
        (took.as_secs_f64() - dur_a / 2.0).abs() < 0.35,
        "2x took {took:?}"
    );
    player.set_speed(1.0);

    println!("SMOKE OK");
}

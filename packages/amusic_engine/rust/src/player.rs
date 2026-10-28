//! Real-time playback: a decode thread fills a lock-free ring buffer, the
//! audio callback runs the DSP chain on whatever it pops and writes the device.
//!
//! The DSP lives in the callback on purpose: equalizer moves are heard at once
//! instead of after the ring buffer has drained. Everything the UI needs is
//! exposed as atomics so the Flutter side can poll without blocking; loading is
//! asynchronous because opening a network source can take a while.

use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{BufferSize, FromSample, SizedSample, Stream, StreamConfig, SupportedBufferSize};

use crate::decode::Decoder;
use crate::pipeline::{EqConfig, Pipeline};
use crate::resample::Resampler;
use crate::stretch::Stretcher;

/// Seconds of audio the ring buffer holds between decoder and device.
const RING_SECONDS: f64 = 0.5;

/// Frames per audio callback we ask the device for. Fewer, bigger callbacks
/// mean fewer wake-ups (about 21/s at 44.1 kHz instead of 86/s), which is what
/// a weak head unit CPU notices; 46 ms of latency is irrelevant for music.
const DEVICE_BUFFER_FRAMES: u32 = 2048;

/// How long the output stays open without playing before it is paused.
const STREAM_IDLE: Duration = Duration::from_secs(3);

/// Decoder thread polling when it has nothing to do.
const IDLE_POLL: Duration = Duration::from_millis(250);

pub const STATE_IDLE: u32 = 0;
pub const STATE_LOADING: u32 = 1;
pub const STATE_READY: u32 = 2;
pub const STATE_ENDED: u32 = 3;
pub const STATE_ERROR: u32 = 4;

/// Where, in ring frames, the audio of a new track starts (gapless advance).
struct Boundary {
    at: u64,
    duration: f64,
}

pub(crate) struct Shared {
    rate: u32,
    playing: AtomicBool,
    state: AtomicU32,
    /// The decoder reached the end of the last queued track.
    eof: AtomicBool,
    volume: AtomicU32,
    speed: AtomicU64,
    /// Position in the current track, seconds; written by the callback.
    pos_secs: AtomicU64,
    /// Position a flush restarts from; written by the decode thread.
    base_secs: AtomicU64,
    duration: AtomicU64,
    /// Counts gapless advances to the queued "next" track.
    advance_seq: AtomicU64,
    /// Counts finished `load` commands (ok or error).
    load_seq: AtomicU64,
    flush_req: AtomicU64,
    flush_ack: AtomicU64,
    pending_cfg: Mutex<Option<EqConfig>>,
    error: Mutex<String>,
    ctl: Sender<Ctl>,
}

impl Shared {
    /// Makes sure the (possibly paused) output stream is running.
    fn wake(&self) {
        let _ = self.ctl.send(Ctl::Wake);
    }
}

/// Messages for the audio thread.
enum Ctl {
    /// Something needs the stream running now (play, load, seek).
    Wake,
    Shutdown,
}

enum Cmd {
    Load { url: String, start: f64 },
    SetNext(Option<String>),
    Seek(f64),
    Stop,
    Shutdown,
}

/// Snapshot polled by the UI.
#[derive(Clone, Copy, Debug)]
pub struct Status {
    pub state: u32,
    pub playing: bool,
    pub position: f64,
    /// Negative when unknown.
    pub duration: f64,
    pub advance_seq: u64,
    pub load_seq: u64,
}

pub struct Player {
    shared: Arc<Shared>,
    tx: Sender<Cmd>,
    threads: Vec<JoinHandle<()>>,
}

type Init = Result<(Arc<Shared>, rtrb::Producer<f32>, rtrb::Producer<Boundary>), String>;

impl Player {
    /// Opens the default output device and starts the (silent) stream.
    pub fn new() -> Result<Self, String> {
        let (init_tx, init_rx) = mpsc::channel::<Init>();
        let (ctl_tx, ctl_rx) = mpsc::channel::<Ctl>();

        // The audio thread owns the cpal stream (it is not Send everywhere).
        let audio = thread::Builder::new()
            .name("amusic-audio".into())
            .spawn(move || audio_thread(init_tx, ctl_tx, ctl_rx))
            .map_err(|e| e.to_string())?;
        let (shared, producer, boundaries) = init_rx.recv().map_err(|e| e.to_string())??;

        let (tx, rx) = mpsc::channel();
        let decode_shared = shared.clone();
        let decode = thread::Builder::new()
            .name("amusic-decode".into())
            .spawn(move || Decoding::new(decode_shared, producer, boundaries).run(rx))
            .map_err(|e| e.to_string())?;

        Ok(Self { shared, tx, threads: vec![audio, decode] })
    }

    /// Starts loading `url` (path, `file://` or `http://`). Returns at once;
    /// watch [`Status::load_seq`] / [`Status::state`] for the result.
    pub fn load(&self, url: &str, start_secs: f64) {
        self.shared.state.store(STATE_LOADING, Ordering::Release);
        self.shared.wake();
        let _ = self.tx.send(Cmd::Load { url: url.to_string(), start: start_secs });
    }

    /// Queues the track that follows the current one so it can start without a
    /// gap. `None` clears it.
    pub fn set_next(&self, url: Option<&str>) {
        let _ = self.tx.send(Cmd::SetNext(url.map(str::to_string)));
    }

    pub fn play(&self) {
        self.shared.playing.store(true, Ordering::Release);
        self.shared.wake();
    }

    pub fn pause(&self) {
        self.shared.playing.store(false, Ordering::Release);
    }

    pub fn stop(&self) {
        self.shared.playing.store(false, Ordering::Release);
        self.shared.state.store(STATE_IDLE, Ordering::Release);
        let _ = self.tx.send(Cmd::Stop);
    }

    pub fn seek(&self, secs: f64) {
        self.shared.wake();
        let _ = self.tx.send(Cmd::Seek(secs));
    }

    pub fn set_volume(&self, v: f32) {
        self.shared.volume.store(v.clamp(0.0, 1.0).to_bits(), Ordering::Relaxed);
    }

    pub fn set_speed(&self, speed: f64) {
        self.shared.speed.store(speed.clamp(0.25, 4.0).to_bits(), Ordering::Relaxed);
    }

    pub fn set_eq(&self, cfg: EqConfig) {
        *self.shared.pending_cfg.lock().unwrap() = Some(cfg);
    }

    pub fn status(&self) -> Status {
        let s = &self.shared;
        let d = f64::from_bits(s.duration.load(Ordering::Acquire));
        Status {
            state: s.state.load(Ordering::Acquire),
            playing: s.playing.load(Ordering::Acquire),
            position: f64::from_bits(s.pos_secs.load(Ordering::Acquire)),
            duration: if d.is_nan() { -1.0 } else { d },
            advance_seq: s.advance_seq.load(Ordering::Acquire),
            load_seq: s.load_seq.load(Ordering::Acquire),
        }
    }

    /// The last error message (cleared by reading).
    pub fn take_error(&self) -> String {
        std::mem::take(&mut *self.shared.error.lock().unwrap())
    }

    pub fn sample_rate(&self) -> u32 {
        self.shared.rate
    }

    /// Blocks until a `load` finished; for tests and simple tools.
    pub fn wait_loaded(&self, timeout: Duration) -> Result<(), String> {
        let start = Instant::now();
        loop {
            match self.shared.state.load(Ordering::Acquire) {
                STATE_READY | STATE_ENDED => return Ok(()),
                STATE_ERROR => return Err(self.take_error()),
                _ => {}
            }
            if start.elapsed() > timeout {
                return Err("timed out loading".into());
            }
            thread::sleep(Duration::from_millis(5));
        }
    }
}

impl Drop for Player {
    fn drop(&mut self) {
        let _ = self.tx.send(Cmd::Shutdown);
        let _ = self.shared.ctl.send(Ctl::Shutdown);
        for t in self.threads.drain(..) {
            let _ = t.join();
        }
    }
}

// ------------------------------------------------------------ audio thread

fn audio_thread(init: Sender<Init>, ctl_tx: Sender<Ctl>, ctl_rx: Receiver<Ctl>) {
    match open_stream(ctl_tx) {
        Ok((stream, shared, producer, boundaries)) => {
            let _ = init.send(Ok((shared.clone(), producer, boundaries)));
            // Keep the stream alive, but let the device sleep when nothing has
            // played for a while: an open stream keeps waking the CPU even
            // while it only outputs silence.
            let mut running = true;
            let mut idle_since = Instant::now();
            loop {
                match ctl_rx.recv_timeout(Duration::from_millis(300)) {
                    Ok(Ctl::Shutdown) | Err(mpsc::RecvTimeoutError::Disconnected) => break,
                    Ok(Ctl::Wake) => {
                        idle_since = Instant::now();
                        if !running && stream.play().is_ok() {
                            running = true;
                        }
                    }
                    Err(mpsc::RecvTimeoutError::Timeout) => {
                        let busy = shared.playing.load(Ordering::Acquire)
                            || shared.state.load(Ordering::Acquire) == STATE_LOADING
                            || shared.flush_req.load(Ordering::Acquire)
                                != shared.flush_ack.load(Ordering::Acquire);
                        if busy {
                            idle_since = Instant::now();
                            if !running && stream.play().is_ok() {
                                running = true;
                            }
                        } else if running && idle_since.elapsed() > STREAM_IDLE {
                            // Some backends cannot pause; then it just keeps running.
                            if stream.pause().is_ok() {
                                running = false;
                            } else {
                                idle_since = Instant::now();
                            }
                        }
                    }
                }
            }
            drop(stream);
        }
        Err(e) => {
            let _ = init.send(Err(e));
        }
    }
}

type Opened = (Stream, Arc<Shared>, rtrb::Producer<f32>, rtrb::Producer<Boundary>);

fn open_stream(ctl: Sender<Ctl>) -> Result<Opened, String> {
    let host = cpal::default_host();
    let device = host.default_output_device().ok_or("no output device")?;
    let supported = device.default_output_config().map_err(|e| e.to_string())?;
    let format = supported.sample_format();
    let buffer = supported.buffer_size().clone();
    let base: StreamConfig = supported.into();
    let rate = base.sample_rate;

    // Bigger device buffers. Some hosts (AAudio) cannot tell the range up
    // front, so ask anyway: if the device refuses, the default config below is
    // the fallback.
    let mut configs = Vec::new();
    let frames = match buffer {
        SupportedBufferSize::Range { min, max } => DEVICE_BUFFER_FRAMES.clamp(min, max),
        SupportedBufferSize::Unknown => DEVICE_BUFFER_FRAMES,
    };
    if frames > 0 {
        configs.push(StreamConfig { buffer_size: BufferSize::Fixed(frames), ..base.clone() });
    }
    configs.push(base);

    let shared = Arc::new(Shared {
        rate,
        playing: AtomicBool::new(false),
        state: AtomicU32::new(STATE_IDLE),
        eof: AtomicBool::new(false),
        volume: AtomicU32::new(1.0f32.to_bits()),
        speed: AtomicU64::new(1.0f64.to_bits()),
        pos_secs: AtomicU64::new(0f64.to_bits()),
        base_secs: AtomicU64::new(0f64.to_bits()),
        duration: AtomicU64::new(f64::NAN.to_bits()),
        advance_seq: AtomicU64::new(0),
        load_seq: AtomicU64::new(0),
        flush_req: AtomicU64::new(0),
        flush_ack: AtomicU64::new(0),
        pending_cfg: Mutex::new(None),
        error: Mutex::new(String::new()),
        ctl,
    });

    let mut last_err = String::from("no usable stream config");
    for config in configs {
        let capacity = (rate as f64 * RING_SECONDS) as usize * 2;
        let (producer, consumer) = rtrb::RingBuffer::new(capacity);
        let (b_prod, b_cons) = rtrb::RingBuffer::new(16);

        use cpal::SampleFormat::*;
        let built = match format {
            F32 => build::<f32>(&device, config, consumer, b_cons, shared.clone()),
            I16 => build::<i16>(&device, config, consumer, b_cons, shared.clone()),
            I32 => build::<i32>(&device, config, consumer, b_cons, shared.clone()),
            other => return Err(format!("unsupported sample format {other}")),
        };
        match built {
            Ok(stream) => {
                stream.play().map_err(|e| e.to_string())?;
                return Ok((stream, shared, producer, b_prod));
            }
            Err(e) => last_err = e,
        }
    }
    Err(last_err)
}

fn build<T>(
    device: &cpal::Device,
    config: StreamConfig,
    mut consumer: rtrb::Consumer<f32>,
    mut boundaries: rtrb::Consumer<Boundary>,
    shared: Arc<Shared>,
) -> Result<Stream, String>
where
    T: SizedSample + FromSample<f32>,
{
    let channels = config.channels as usize;
    let rate = config.sample_rate as f64;
    let mut pipeline = Pipeline::new(config.sample_rate);
    let mut scratch: Vec<f32> = Vec::new();
    let mut vol = 1.0f32;
    // Frames popped since the last flush (the clock `Boundary::at` refers to).
    let mut consumed: u64 = 0;

    device
        .build_output_stream(
            config,
            move |data: &mut [T], _| {
                let frames = data.len() / channels;

                // A seek / load asked for the queued audio to be dropped.
                let req = shared.flush_req.load(Ordering::Acquire);
                if req != shared.flush_ack.load(Ordering::Relaxed) {
                    while consumer.pop().is_ok() {}
                    while boundaries.pop().is_ok() {}
                    consumed = 0;
                    let base = shared.base_secs.load(Ordering::Acquire);
                    shared.pos_secs.store(base, Ordering::Release);
                    shared.flush_ack.store(req, Ordering::Release);
                }

                if let Ok(mut pending) = shared.pending_cfg.try_lock() {
                    if let Some(cfg) = pending.take() {
                        pipeline.set_config(&cfg);
                    }
                }

                scratch.clear();
                scratch.resize(frames * 2, 0.0);
                let mut got = 0;
                if shared.playing.load(Ordering::Acquire)
                    && shared.state.load(Ordering::Acquire) == STATE_READY
                {
                    // Whole frames only, taken in one go.
                    let take = consumer.slots().min(frames * 2) & !1;
                    if take > 0 {
                        if let Ok(chunk) = consumer.read_chunk(take) {
                            let (a, b) = chunk.as_slices();
                            scratch[..a.len()].copy_from_slice(a);
                            scratch[a.len()..a.len() + b.len()].copy_from_slice(b);
                            chunk.commit_all();
                            got = take / 2;
                        }
                    }
                    if got < frames && shared.eof.load(Ordering::Acquire) && consumer.is_empty() {
                        shared.state.store(STATE_ENDED, Ordering::Release);
                        shared.playing.store(false, Ordering::Release);
                    }
                    pipeline.process(&mut scratch[..got * 2]);

                    // Position: frames played, scaled by the playback speed.
                    let speed = f64::from_bits(shared.speed.load(Ordering::Relaxed));
                    consumed += got as u64;
                    let mut pos = f64::from_bits(shared.pos_secs.load(Ordering::Acquire))
                        + got as f64 * speed / rate;
                    if let Ok(b) = boundaries.peek() {
                        if b.at <= consumed {
                            // The queued track began `consumed - at` frames ago.
                            pos = (consumed - b.at) as f64 * speed / rate;
                            shared.duration.store(b.duration.to_bits(), Ordering::Release);
                            shared.advance_seq.fetch_add(1, Ordering::AcqRel);
                            let _ = boundaries.pop();
                        }
                    }
                    shared.pos_secs.store(pos.to_bits(), Ordering::Release);
                }

                // Volume with a short ramp so changes do not click.
                let target = f32::from_bits(shared.volume.load(Ordering::Relaxed));
                for (i, frame) in data.chunks_mut(channels).enumerate() {
                    vol += (target - vol) * 0.002;
                    let (l, r) = (scratch[i * 2] * vol, scratch[i * 2 + 1] * vol);
                    match channels {
                        1 => frame[0] = T::from_sample((l + r) * 0.5),
                        _ => {
                            frame[0] = T::from_sample(l);
                            frame[1] = T::from_sample(r);
                            for s in frame.iter_mut().skip(2) {
                                *s = T::from_sample(0.0);
                            }
                        }
                    }
                }
            },
            |e| eprintln!("audio stream error: {e}"),
            None,
        )
        .map_err(|e| e.to_string())
}

// ----------------------------------------------------------- decode thread

struct Source {
    decoder: Decoder,
    resampler: Resampler,
    stretcher: Stretcher,
}

impl Source {
    fn new(decoder: Decoder, rate: u32) -> Self {
        let resampler = Resampler::new(decoder.sample_rate, rate);
        Self { decoder, resampler, stretcher: Stretcher::new(rate) }
    }

    /// Back to the start of the stream state after a seek.
    fn reset(&mut self, rate: u32) {
        self.resampler = Resampler::new(self.decoder.sample_rate, rate);
        self.stretcher.reset();
    }
}

enum Next {
    None,
    Opening(Receiver<Result<Decoder, String>>),
    Ready(Decoder),
}

struct Decoding {
    shared: Arc<Shared>,
    producer: rtrb::Producer<f32>,
    boundaries: rtrb::Producer<Boundary>,
    rate: u32,
    source: Option<Source>,
    next: Next,
    /// Decoded frames that did not fit into the ring yet.
    backlog: Vec<f32>,
    backlog_pos: usize,
    /// Frames pushed into the ring since the last flush.
    pushed: u64,
    raw: Vec<f32>,
    resampled: Vec<f32>,
}

impl Decoding {
    fn new(shared: Arc<Shared>, producer: rtrb::Producer<f32>, boundaries: rtrb::Producer<Boundary>) -> Self {
        let rate = shared.rate;
        Self {
            shared,
            producer,
            boundaries,
            rate,
            source: None,
            next: Next::None,
            backlog: Vec::new(),
            backlog_pos: 0,
            pushed: 0,
            raw: Vec::new(),
            resampled: Vec::new(),
        }
    }

    /// Drops queued audio and waits (briefly) for the callback to confirm.
    fn flush(&mut self, base_secs: f64) {
        self.backlog.clear();
        self.backlog_pos = 0;
        self.pushed = 0;
        self.shared.base_secs.store(base_secs.to_bits(), Ordering::Release);
        let req = self.shared.flush_req.fetch_add(1, Ordering::AcqRel) + 1;
        // The callback does the flush, so a paused stream has to wake up first.
        self.shared.wake();
        let start = Instant::now();
        while self.shared.flush_ack.load(Ordering::Acquire) != req
            && start.elapsed() < Duration::from_millis(400)
        {
            thread::sleep(Duration::from_millis(2));
        }
    }

    fn fail(&self, msg: String) {
        *self.shared.error.lock().unwrap() = msg;
        self.shared.state.store(STATE_ERROR, Ordering::Release);
        self.shared.playing.store(false, Ordering::Release);
    }

    fn run(mut self, rx: Receiver<Cmd>) {
        // How long to wait for a command before working again. The wait is
        // what keeps the thread asleep while the ring buffer is full; a command
        // ends it at once.
        let mut wait = Duration::ZERO;
        loop {
            let cmd = if wait.is_zero() {
                match rx.try_recv() {
                    Ok(c) => Some(c),
                    Err(mpsc::TryRecvError::Empty) => None,
                    Err(mpsc::TryRecvError::Disconnected) => return,
                }
            } else {
                match rx.recv_timeout(wait) {
                    Ok(c) => Some(c),
                    Err(mpsc::RecvTimeoutError::Timeout) => None,
                    Err(mpsc::RecvTimeoutError::Disconnected) => return,
                }
            };

            match cmd {
                Some(Cmd::Shutdown) => return,
                Some(Cmd::Stop) => {
                    self.source = None;
                    self.next = Next::None;
                    self.shared.eof.store(false, Ordering::Release);
                    self.flush(0.0);
                }
                Some(Cmd::Load { url, start }) => self.load(&url, start),
                Some(Cmd::SetNext(url)) => self.set_next(url),
                Some(Cmd::Seek(secs)) => self.seek(secs),
                None => {}
            }

            self.poll_next();
            wait = if self.source.is_some() { self.pump() } else { IDLE_POLL };
        }
    }

    fn load(&mut self, url: &str, start: f64) {
        self.next = Next::None;
        self.source = None;
        self.shared.eof.store(false, Ordering::Release);
        match Decoder::open_any(url) {
            Ok(mut decoder) => {
                let duration = decoder.duration.unwrap_or(f64::NAN);
                self.shared.duration.store(duration.to_bits(), Ordering::Release);
                let mut base = 0.0;
                if start > 0.05 {
                    match decoder.seek(start) {
                        Ok(actual) => base = actual,
                        Err(e) => eprintln!("initial seek failed: {e}"),
                    }
                }
                self.source = Some(Source::new(decoder, self.rate));
                self.flush(base);
                self.shared.state.store(STATE_READY, Ordering::Release);
            }
            Err(e) => {
                self.flush(0.0);
                self.fail(e);
            }
        }
        self.shared.load_seq.fetch_add(1, Ordering::AcqRel);
    }

    fn set_next(&mut self, url: Option<String>) {
        self.next = Next::None;
        let Some(url) = url else { return };
        let (tx, rx) = mpsc::channel();
        // Opening may block on the network; do it off the decode loop.
        thread::spawn(move || {
            let _ = tx.send(Decoder::open_any(&url));
        });
        self.next = Next::Opening(rx);
    }

    fn poll_next(&mut self) {
        if let Next::Opening(rx) = &self.next {
            match rx.try_recv() {
                Ok(Ok(decoder)) => self.next = Next::Ready(decoder),
                Ok(Err(e)) => {
                    eprintln!("could not prefetch the next track: {e}");
                    self.next = Next::None;
                }
                Err(mpsc::TryRecvError::Empty) => {}
                Err(mpsc::TryRecvError::Disconnected) => self.next = Next::None,
            }
        }
    }

    fn seek(&mut self, secs: f64) {
        let rate = self.rate;
        let Some(src) = self.source.as_mut() else { return };
        match src.decoder.seek(secs) {
            Ok(actual) => {
                src.reset(rate);
                self.shared.eof.store(false, Ordering::Release);
                if self.shared.state.load(Ordering::Acquire) == STATE_ENDED {
                    self.shared.state.store(STATE_READY, Ordering::Release);
                }
                self.flush(actual);
            }
            Err(e) => eprintln!("seek failed: {e}"),
        }
    }

    /// Moves as much of the backlog as fits into the ring, in one go.
    fn push_backlog(&mut self) {
        let rest = self.backlog.len() - self.backlog_pos;
        let n = rest.min(self.producer.slots());
        if n == 0 {
            return;
        }
        if let Ok(chunk) = self.producer.write_chunk_uninit(n) {
            let from = self.backlog_pos;
            self.backlog_pos += chunk.fill_from_iter(self.backlog[from..from + n].iter().copied());
        }
    }

    /// How long to sleep while the ring is too full to decode into: until the
    /// device has drained enough to be worth waking for.
    fn ring_wait(&self) -> Duration {
        if !self.shared.playing.load(Ordering::Acquire) {
            // Nothing drains the ring while paused.
            return IDLE_POLL;
        }
        let missing = 8192usize.saturating_sub(self.producer.slots()).max(1);
        let secs = missing as f64 / (self.rate as f64 * 2.0);
        Duration::from_secs_f64(secs).clamp(Duration::from_millis(10), Duration::from_millis(120))
    }

    /// Pushes the backlog, then decodes more while the ring has room. Returns
    /// how long the caller may sleep before pumping again.
    fn pump(&mut self) -> Duration {
        loop {
            self.push_backlog();
            if self.backlog_pos < self.backlog.len() {
                return self.ring_wait();
            }
            self.pushed += (self.backlog.len() / 2) as u64;
            self.backlog.clear();
            self.backlog_pos = 0;

            if self.shared.eof.load(Ordering::Acquire) {
                return IDLE_POLL;
            }
            if self.producer.slots() < 8192 {
                return self.ring_wait();
            }

            let speed = f64::from_bits(self.shared.speed.load(Ordering::Relaxed));
            let src = self.source.as_mut().unwrap();
            src.stretcher.set_speed(speed);
            self.raw.clear();
            match src.decoder.next_frames(&mut self.raw) {
                Ok(true) => {
                    self.resampled.clear();
                    src.resampler.process(&self.raw, &mut self.resampled);
                    src.stretcher.process(&self.resampled, &mut self.backlog);
                }
                Ok(false) => {
                    // The track is done: drain the stretcher, then either roll
                    // straight into the queued next track or finish.
                    src.stretcher.finish(&mut self.backlog);
                    match std::mem::replace(&mut self.next, Next::None) {
                        Next::Ready(decoder) => {
                            self.queue_next_track(decoder);
                        }
                        Next::Opening(rx) => {
                            // Still opening: wait for it instead of ending.
                            self.next = Next::Opening(rx);
                            if self.backlog.is_empty() {
                                return Duration::from_millis(10);
                            }
                        }
                        Next::None => {
                            self.shared.eof.store(true, Ordering::Release);
                            if self.backlog.is_empty() {
                                return IDLE_POLL;
                            }
                        }
                    }
                }
                Err(e) => {
                    eprintln!("decode error: {e}");
                    self.shared.eof.store(true, Ordering::Release);
                    return IDLE_POLL;
                }
            }
        }
    }

    /// Continues with `decoder` right after the frames already queued. The
    /// boundary tells the callback where the new track starts.
    fn queue_next_track(&mut self, decoder: Decoder) {
        // Everything decoded so far must be in the ring before the boundary.
        self.push_backlog();
        if self.backlog_pos < self.backlog.len() {
            // Ring is full; retry the switch on the next pump.
            self.next = Next::Ready(decoder);
            return;
        }
        self.pushed += (self.backlog.len() / 2) as u64;
        self.backlog.clear();
        self.backlog_pos = 0;
        let duration = decoder.duration.unwrap_or(f64::NAN);
        let _ = self.boundaries.push(Boundary { at: self.pushed, duration });
        self.source = Some(Source::new(decoder, self.rate));
    }
}

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

#[cfg(not(target_os = "android"))]
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
#[cfg(not(target_os = "android"))]
use cpal::{BufferSize, FromSample, SizedSample, StreamConfig, SupportedBufferSize};

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

/// Transport fade duration used when pausing and resuming. The fade is done
/// in the audio callback so it is independent of Flutter scheduling and the
/// platform's audio focus implementation.
const TRANSPORT_FADE: Duration = Duration::from_millis(500);

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
    /// Loudness normalisation of the current track, linear.
    gain: AtomicU32,
    /// Gain of the queued track, applied where it starts; NaN when unset.
    next_gain: AtomicU32,
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

        // The audio thread owns the output stream (it is not Send everywhere).
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

        Ok(Self {
            shared,
            tx,
            threads: vec![audio, decode],
        })
    }

    /// Starts loading `url` (path, `file://` or `http://`). Returns at once;
    /// watch [`Status::load_seq`] / [`Status::state`] for the result.
    pub fn load(&self, url: &str, start_secs: f64) {
        self.shared.state.store(STATE_LOADING, Ordering::Release);
        self.shared.wake();
        let _ = self.tx.send(Cmd::Load {
            url: url.to_string(),
            start: start_secs,
        });
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
        // A paused stream may already be sleeping on a backend that stopped
        // its device stream. Wake it so the callback can finish the fade out.
        self.shared.wake();
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
        self.shared
            .volume
            .store(v.clamp(0.0, 1.0).to_bits(), Ordering::Relaxed);
    }

    /// Loudness normalisation for the track playing now, in dB (ramped).
    pub fn set_gain_db(&self, db: f32) {
        self.shared
            .gain
            .store(db_to_linear(db).to_bits(), Ordering::Relaxed);
    }

    /// Gain for the queued track, applied the instant it starts; NaN clears.
    pub fn set_next_gain_db(&self, db: f32) {
        let v = if db.is_nan() {
            f32::NAN
        } else {
            db_to_linear(db)
        };
        self.shared.next_gain.store(v.to_bits(), Ordering::Relaxed);
    }

    pub fn set_speed(&self, speed: f64) {
        self.shared
            .speed
            .store(speed.clamp(0.25, 4.0).to_bits(), Ordering::Relaxed);
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

/// Normalisation never boosts by more than this, nor cuts by more than 24 dB.
fn db_to_linear(db: f32) -> f32 {
    10f32.powf(db.clamp(-24.0, 12.0) / 20.0)
}

/// Moves a linear gain toward its target by at most one callback sample.
/// Keeping this as a bounded step avoids overshoot when a play request arrives
/// while a pause fade is still in progress.
fn move_towards(value: f32, target: f32, step: f32) -> f32 {
    if (value - target).abs() <= step {
        target
    } else if value < target {
        value + step
    } else {
        value - step
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

/// A device sample format the renderer can write.
trait OutSample {
    fn from_f32(v: f32) -> Self;
}

#[cfg(not(target_os = "android"))]
impl<T: FromSample<f32>> OutSample for T {
    fn from_f32(v: f32) -> Self {
        <T as FromSample<f32>>::from_sample_(v)
    }
}

#[cfg(target_os = "android")]
impl OutSample for f32 {
    fn from_f32(v: f32) -> Self {
        v
    }
}

/// Everything the audio callback owns: pops the ring buffer, runs the DSP
/// chain and writes the device buffer. Backend-independent; cpal (desktop, iOS)
/// and Oboe (Android) both just call [`Renderer::render`].
struct Renderer {
    channels: usize,
    rate: f64,
    shared: Arc<Shared>,
    consumer: rtrb::Consumer<f32>,
    boundaries: rtrb::Consumer<Boundary>,
    pipeline: Pipeline,
    scratch: Vec<f32>,
    vol: f32,
    norm: f32,
    // `playing` is the transport request exposed to the UI. `output_active`
    // stays true for the short pause fade, allowing the callback to drain the
    // already-decoded frames while the output gain reaches zero.
    output_active: bool,
    fade_step: f32,
    transport_gain: f32,
    // Frames popped since the last flush (the clock `Boundary::at` refers to).
    consumed: u64,
}

impl Renderer {
    fn new(
        channels: usize,
        rate: u32,
        consumer: rtrb::Consumer<f32>,
        boundaries: rtrb::Consumer<Boundary>,
        shared: Arc<Shared>,
    ) -> Self {
        Self {
            channels,
            rate: rate as f64,
            shared,
            consumer,
            boundaries,
            pipeline: Pipeline::new(rate),
            scratch: Vec::new(),
            vol: 1.0,
            norm: 1.0,
            output_active: false,
            fade_step: 1.0 / (rate as f32 * TRANSPORT_FADE.as_secs_f32()),
            transport_gain: 0.0,
            consumed: 0,
        }
    }

    /// Fills one device buffer of interleaved samples.
    fn render<T>(&mut self, data: &mut [T])
    where
        T: OutSample,
    {
        let channels = self.channels;
        let frames = data.len() / channels;

        // A seek / load asked for the queued audio to be dropped.
        let req = self.shared.flush_req.load(Ordering::Acquire);
        if req != self.shared.flush_ack.load(Ordering::Relaxed) {
            while self.consumer.pop().is_ok() {}
            while self.boundaries.pop().is_ok() {}
            self.consumed = 0;
            let base = self.shared.base_secs.load(Ordering::Acquire);
            self.shared.pos_secs.store(base, Ordering::Release);
            self.shared.flush_ack.store(req, Ordering::Release);
        }

        if let Ok(mut pending) = self.shared.pending_cfg.try_lock() {
            if let Some(cfg) = pending.take() {
                self.pipeline.set_config(&cfg);
            }
        }

        self.scratch.clear();
        self.scratch.resize(frames * 2, 0.0);
        let mut gain_switch: Option<(usize, f32)> = None;
        let norm_target = f32::from_bits(self.shared.gain.load(Ordering::Relaxed));
        let mut got = 0;
        let requested_playing = self.shared.playing.load(Ordering::Acquire);
        if requested_playing {
            self.output_active = true;
        }
        if self.output_active && self.shared.state.load(Ordering::Acquire) == STATE_READY {
            // Whole frames only, taken in one go.
            let take = self.consumer.slots().min(frames * 2) & !1;
            if take > 0 {
                if let Ok(chunk) = self.consumer.read_chunk(take) {
                    let (a, b) = chunk.as_slices();
                    self.scratch[..a.len()].copy_from_slice(a);
                    self.scratch[a.len()..a.len() + b.len()].copy_from_slice(b);
                    chunk.commit_all();
                    got = take / 2;
                }
            }
            if got < frames && self.shared.eof.load(Ordering::Acquire) && self.consumer.is_empty() {
                self.shared.state.store(STATE_ENDED, Ordering::Release);
                self.shared.playing.store(false, Ordering::Release);
            }
            self.pipeline.process(&mut self.scratch[..got * 2]);

            // Position: frames played, scaled by the playback speed.
            let speed = f64::from_bits(self.shared.speed.load(Ordering::Relaxed));
            let consumed_before = self.consumed;
            self.consumed += got as u64;
            let mut pos = f64::from_bits(self.shared.pos_secs.load(Ordering::Acquire))
                + got as f64 * speed / self.rate;
            if let Ok(b) = self.boundaries.peek() {
                if b.at <= self.consumed {
                    let at = b.at;
                    // The queued track began `consumed - at` frames ago.
                    pos = (self.consumed - b.at) as f64 * speed / self.rate;
                    self.shared
                        .duration
                        .store(b.duration.to_bits(), Ordering::Release);
                    self.shared.advance_seq.fetch_add(1, Ordering::AcqRel);
                    let _ = self.boundaries.pop();
                    // The queued track's own gain, from its first frame.
                    let next = f32::from_bits(self.shared.next_gain.load(Ordering::Relaxed));
                    if !next.is_nan() {
                        gain_switch =
                            Some((at.saturating_sub(consumed_before) as usize, next));
                        self.shared
                            .next_gain
                            .store(f32::NAN.to_bits(), Ordering::Relaxed);
                        self.shared.gain.store(next.to_bits(), Ordering::Relaxed);
                    }
                }
            }
            self.shared.pos_secs.store(pos.to_bits(), Ordering::Release);
        }

        // Volume with a short ramp so changes do not click.
        let target = f32::from_bits(self.shared.volume.load(Ordering::Relaxed));
        let transport_target = if requested_playing { 1.0 } else { 0.0 };
        for (i, frame) in data.chunks_mut(channels).enumerate() {
            self.vol += (target - self.vol) * 0.002;
            // The previous track's gain holds until the new one begins.
            let wanted = match gain_switch {
                Some((at, g)) if i >= at => g,
                _ => norm_target,
            };
            self.norm += (wanted - self.norm) * 0.002;
            self.transport_gain = move_towards(self.transport_gain, transport_target, self.fade_step);
            let gain = self.vol * self.norm * self.transport_gain;
            let (l, r) = (self.scratch[i * 2] * gain, self.scratch[i * 2 + 1] * gain);
            match self.channels {
                1 => frame[0] = T::from_f32((l + r) * 0.5),
                _ => {
                    frame[0] = T::from_f32(l);
                    frame[1] = T::from_f32(r);
                    for s in frame.iter_mut().skip(2) {
                        *s = T::from_f32(0.0);
                    }
                }
            }
        }
        if !requested_playing && self.transport_gain <= f32::EPSILON {
            self.output_active = false;
        }
    }
}

fn new_shared(rate: u32, ctl: Sender<Ctl>) -> Arc<Shared> {
    Arc::new(Shared {
        rate,
        playing: AtomicBool::new(false),
        state: AtomicU32::new(STATE_IDLE),
        eof: AtomicBool::new(false),
        volume: AtomicU32::new(1.0f32.to_bits()),
        gain: AtomicU32::new(1.0f32.to_bits()),
        next_gain: AtomicU32::new(f32::NAN.to_bits()),
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
    })
}

type Opened = (
    Output,
    Arc<Shared>,
    rtrb::Producer<f32>,
    rtrb::Producer<Boundary>,
);

fn ring(rate: u32) -> (rtrb::Producer<f32>, rtrb::Consumer<f32>) {
    rtrb::RingBuffer::new((rate as f64 * RING_SECONDS) as usize * 2)
}

#[cfg(not(target_os = "android"))]
use self::cpal_out::{open_stream, Output};
#[cfg(target_os = "android")]
use self::oboe_out::{open_stream, Output};

#[cfg(not(target_os = "android"))]
mod cpal_out {
    use super::*;

    pub struct Output(cpal::Stream);

    impl Output {
        pub fn play(&self) -> Result<(), String> {
            self.0.play().map_err(|e| e.to_string())
        }

        pub fn pause(&self) -> Result<(), String> {
            self.0.pause().map_err(|e| e.to_string())
        }
    }

    pub fn open_stream(ctl: Sender<Ctl>) -> Result<Opened, String> {
        let host = cpal::default_host();
        let device = host.default_output_device().ok_or("no output device")?;
        let supported = device.default_output_config().map_err(|e| e.to_string())?;
        let format = supported.sample_format();
        let buffer = supported.buffer_size().clone();
        let base: StreamConfig = supported.into();
        let rate = base.sample_rate;

        // Bigger device buffers. Some hosts cannot tell the range up front, so
        // ask anyway: if the device refuses, the default config below is the
        // fallback.
        let mut configs = Vec::new();
        let frames = match buffer {
            SupportedBufferSize::Range { min, max } => DEVICE_BUFFER_FRAMES.clamp(min, max),
            SupportedBufferSize::Unknown => DEVICE_BUFFER_FRAMES,
        };
        if frames > 0 {
            configs.push(StreamConfig {
                buffer_size: BufferSize::Fixed(frames),
                ..base.clone()
            });
        }
        configs.push(base);

        let shared = new_shared(rate, ctl);

        let mut last_err = String::from("no usable stream config");
        for config in configs {
            let (producer, consumer) = ring(rate);
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
                    return Ok((Output(stream), shared, producer, b_prod));
                }
                Err(e) => last_err = e,
            }
        }
        Err(last_err)
    }

    fn build<T>(
        device: &cpal::Device,
        config: StreamConfig,
        consumer: rtrb::Consumer<f32>,
        boundaries: rtrb::Consumer<Boundary>,
        shared: Arc<Shared>,
    ) -> Result<cpal::Stream, String>
    where
        T: SizedSample + FromSample<f32>,
    {
        let mut renderer = Renderer::new(
            config.channels as usize,
            config.sample_rate,
            consumer,
            boundaries,
            shared,
        );
        device
            .build_output_stream(
                config,
                move |data: &mut [T], _| renderer.render(data),
                |e| eprintln!("audio stream error: {e}"),
                None,
            )
            .map_err(|e| e.to_string())
    }
}

/// Android plays through Oboe: it uses AAudio where the system has it (8.0+)
/// and OpenSL ES on older systems, so the app still installs on Android 7.
#[cfg(target_os = "android")]
mod oboe_out {
    use super::*;
    use oboe::{
        AudioOutputCallback, AudioOutputStream, AudioOutputStreamSafe, AudioStream,
        AudioStreamAsync, AudioStreamBuilder, DataCallbackResult, Output as OboeOutput, PerformanceMode,
        SampleRateConversionQuality, Stereo,
    };

    /// Oboe converts to the device rate itself, so the engine always runs at a
    /// fixed rate and the rest of the pipeline never has to care.
    const RATE: u32 = 48_000;

    pub struct Output(std::cell::RefCell<AudioStreamAsync<OboeOutput, Callback>>);

    impl Output {
        pub fn play(&self) -> Result<(), String> {
            self.0.borrow_mut().request_start().map_err(|e| e.to_string())
        }

        pub fn pause(&self) -> Result<(), String> {
            self.0.borrow_mut().request_pause().map_err(|e| e.to_string())
        }
    }

    pub struct Callback {
        renderer: Renderer,
        interleaved: Vec<f32>,
    }

    impl AudioOutputCallback for Callback {
        type FrameType = (f32, Stereo);

        fn on_audio_ready(
            &mut self,
            _stream: &mut dyn AudioOutputStreamSafe,
            frames: &mut [(f32, f32)],
        ) -> DataCallbackResult {
            self.interleaved.resize(frames.len() * 2, 0.0);
            self.renderer.render(&mut self.interleaved);
            for (frame, lr) in frames.iter_mut().zip(self.interleaved.chunks_exact(2)) {
                *frame = (lr[0], lr[1]);
            }
            DataCallbackResult::Continue
        }

        fn on_error_after_close(
            &mut self,
            _stream: &mut dyn AudioOutputStreamSafe,
            error: oboe::Error,
        ) {
            eprintln!("audio stream error: {error}");
        }
    }

    pub fn open_stream(ctl: Sender<Ctl>) -> Result<Opened, String> {
        let shared = new_shared(RATE, ctl);
        let (producer, consumer) = ring(RATE);
        let (b_prod, b_cons) = rtrb::RingBuffer::new(16);
        let renderer = Renderer::new(2, RATE, consumer, b_cons, shared.clone());

        let mut stream = AudioStreamBuilder::default()
            .set_output()
            .set_stereo()
            .set_f32()
            .set_sample_rate(RATE as i32)
            .set_sample_rate_conversion_quality(SampleRateConversionQuality::Medium)
            .set_performance_mode(PerformanceMode::PowerSaving)
            .set_frames_per_callback(DEVICE_BUFFER_FRAMES as i32)
            .set_callback(Callback {
                renderer,
                interleaved: Vec::new(),
            })
            .open_stream()
            .map_err(|e| e.to_string())?;
        stream.request_start().map_err(|e| e.to_string())?;
        Ok((Output(std::cell::RefCell::new(stream)), shared, producer, b_prod))
    }
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
        Self {
            decoder,
            resampler,
            stretcher: Stretcher::new(rate),
        }
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
    fn new(
        shared: Arc<Shared>,
        producer: rtrb::Producer<f32>,
        boundaries: rtrb::Producer<Boundary>,
    ) -> Self {
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
        self.shared
            .base_secs
            .store(base_secs.to_bits(), Ordering::Release);
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
            wait = if self.source.is_some() {
                self.pump()
            } else {
                IDLE_POLL
            };
        }
    }

    fn load(&mut self, url: &str, start: f64) {
        self.next = Next::None;
        self.source = None;
        self.shared.eof.store(false, Ordering::Release);
        match Decoder::open_any(url) {
            Ok(mut decoder) => {
                let duration = decoder.duration.unwrap_or(f64::NAN);
                self.shared
                    .duration
                    .store(duration.to_bits(), Ordering::Release);
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
        let Some(src) = self.source.as_mut() else {
            return;
        };
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
        let _ = self.boundaries.push(Boundary {
            at: self.pushed,
            duration,
        });
        self.source = Some(Source::new(decoder, self.rate));
    }
}

#[cfg(test)]
mod tests {
    use super::{move_towards, TRANSPORT_FADE};

    #[test]
    fn transport_fade_reaches_both_endpoints_without_overshoot() {
        let step = 1.0 / (48_000.0 * TRANSPORT_FADE.as_secs_f32());
        // Add a couple of samples for floating-point rounding in the step.
        let samples = (48_000.0 * TRANSPORT_FADE.as_secs_f32()).ceil() as usize + 2;
        let mut gain = 0.0;
        for _ in 0..samples {
            gain = move_towards(gain, 1.0, step);
            if gain == 1.0 {
                break;
            }
        }
        assert_eq!(gain, 1.0);

        for _ in 0..samples {
            gain = move_towards(gain, 0.0, step);
            if gain == 0.0 {
                break;
            }
        }
        assert_eq!(gain, 0.0);
    }

    #[test]
    fn transport_fade_can_reverse_while_in_progress() {
        let step = 1.0 / (48_000.0 * TRANSPORT_FADE.as_secs_f32());
        let rising = move_towards(0.2, 1.0, step);
        let falling = move_towards(rising, 0.0, step);
        assert!(rising > 0.2);
        assert!(falling < rising);
        assert!(falling > 0.0);
    }
}

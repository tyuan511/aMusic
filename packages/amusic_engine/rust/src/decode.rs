//! Container + codec decoding through Symphonia, always yielding interleaved
//! stereo `f32`.

use std::fs::File;
use std::path::Path;

use symphonia::core::codecs::audio::{AudioDecoder, AudioDecoderOptions};
use symphonia::core::codecs::CodecParameters;
use symphonia::core::errors::Error;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, FormatReader, SeekMode, SeekTo, TrackType};
use symphonia::core::io::{MediaSource, MediaSourceStream, MediaSourceStreamOptions};
use symphonia::core::meta::MetadataOptions;
use symphonia::core::units::Time;

pub struct Decoder {
    format: Box<dyn FormatReader>,
    decoder: Box<dyn AudioDecoder>,
    track_id: u32,
    /// Sample rate of the decoded audio.
    pub sample_rate: u32,
    /// Length in seconds, when the container says.
    pub duration: Option<f64>,
    scratch: Vec<f32>,
}

impl Decoder {
    /// Opens a local path, a `file://` URL or an `http://` URL.
    pub fn open_any(location: &str) -> Result<Self, String> {
        if location.starts_with("http://") {
            let source =
                crate::http::HttpSource::open(location).map_err(|e| format!("http: {e}"))?;
            let path = location.split(['?', '#']).next().unwrap_or(location);
            Self::from_source(
                Box::new(source),
                Path::new(path).extension().and_then(|e| e.to_str()),
            )
        } else if location.starts_with("https://") {
            Err("https is not supported yet".into())
        } else {
            let path = location.strip_prefix("file://").unwrap_or(location);
            Self::open(Path::new(path))
        }
    }

    pub fn open(path: &Path) -> Result<Self, String> {
        let file = File::open(path).map_err(|e| format!("open: {e}"))?;
        Self::from_source(Box::new(file), path.extension().and_then(|e| e.to_str()))
    }

    fn from_source(source: Box<dyn MediaSource>, ext: Option<&str>) -> Result<Self, String> {
        let mss = MediaSourceStream::new(source, MediaSourceStreamOptions::default());
        let mut hint = Hint::new();
        if let Some(ext) = ext {
            hint.with_extension(ext);
        }
        let format = symphonia::default::get_probe()
            .probe(
                &hint,
                mss,
                FormatOptions::default(),
                MetadataOptions::default(),
            )
            .map_err(|e| format!("probe: {e}"))?;

        let track = format
            .default_track(TrackType::Audio)
            .ok_or("no audio track")?;
        let params = match &track.codec_params {
            Some(CodecParameters::Audio(p)) => p.clone(),
            _ => return Err("no audio codec parameters".into()),
        };
        let track_id = track.id;
        let sample_rate = params.sample_rate.ok_or("unknown sample rate")?;
        let duration = track.num_frames.map(|n| n as f64 / sample_rate as f64);
        let decoder = symphonia::default::get_codecs()
            .make_audio_decoder(&params, &AudioDecoderOptions::default())
            .map_err(|e| format!("decoder: {e}"))?;

        Ok(Self {
            format,
            decoder,
            track_id,
            sample_rate,
            duration,
            scratch: Vec::new(),
        })
    }

    /// Appends the next packet's frames (stereo, interleaved) to `out`.
    /// Returns `Ok(false)` at the end of the stream.
    pub fn next_frames(&mut self, out: &mut Vec<f32>) -> Result<bool, String> {
        loop {
            let packet = match self.format.next_packet() {
                Ok(Some(p)) => p,
                Ok(None) => return Ok(false),
                Err(Error::IoError(e)) if e.kind() == std::io::ErrorKind::UnexpectedEof => {
                    return Ok(false)
                }
                Err(Error::ResetRequired) => {
                    self.decoder.reset();
                    continue;
                }
                Err(e) => return Err(format!("read: {e}")),
            };
            if packet.track_id != self.track_id {
                continue;
            }
            match self.decoder.decode(&packet) {
                Ok(buf) => {
                    let channels = buf.spec().channels().count();
                    self.scratch.clear();
                    buf.copy_to_vec_interleaved::<f32>(&mut self.scratch);
                    to_stereo(&self.scratch, channels, out);
                    return Ok(true);
                }
                // A corrupt packet: skip it, keep playing.
                Err(Error::DecodeError(_)) => continue,
                Err(e) => return Err(format!("decode: {e}")),
            }
        }
    }

    /// Seeks and returns the position actually reached, in seconds.
    pub fn seek(&mut self, secs: f64) -> Result<f64, String> {
        let time = Time::try_from_secs_f64(secs.max(0.0)).ok_or("bad seek time")?;
        let to = SeekTo::Time {
            time,
            track_id: Some(self.track_id),
        };
        let seeked = self
            .format
            .seek(SeekMode::Accurate, to)
            .map_err(|e| format!("seek: {e}"))?;
        self.decoder.reset();
        let tb = self
            .format
            .tracks()
            .iter()
            .find(|t| t.id == self.track_id)
            .and_then(|t| t.time_base);
        Ok(tb
            .and_then(|tb| tb.calc_time(seeked.actual_ts))
            .map(|t| t.as_secs_f64())
            .unwrap_or(secs))
    }
}

/// Down/up-mixes any channel layout to interleaved stereo.
fn to_stereo(src: &[f32], channels: usize, out: &mut Vec<f32>) {
    match channels {
        0 => {}
        1 => {
            for &s in src {
                out.push(s);
                out.push(s);
            }
        }
        2 => out.extend_from_slice(src),
        n => {
            // L R C ...: fold the centre in, drop the rest (spike level).
            for frame in src.chunks_exact(n) {
                let c = frame[2] * 0.707;
                out.push(frame[0] + c);
                out.push(frame[1] + c);
            }
        }
    }
}

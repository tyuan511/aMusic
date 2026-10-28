//! Tag and duration reader for local audio files (mp3, flac, m4a, ogg, wav, aac).
//!
//! Symphonia parses the containers; this module only picks the few fields the
//! library needs and never fails: an unreadable file yields empty metadata.

use std::fs::File;
use std::io::{Cursor, Read, Seek, SeekFrom};
use std::path::Path;

use symphonia::core::codecs::CodecParameters;
use symphonia::core::common::Limit;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, FormatReader, TrackType};
use symphonia::core::io::{MediaSource, MediaSourceStream, MediaSourceStreamOptions};
use symphonia::core::meta::{MetadataContainer, MetadataOptions, StandardTag, StandardVisualKey};
use symphonia::core::units::Duration;

/// Covers above this are skipped.
const MAX_TAG_BYTES: usize = 16 * 1024 * 1024;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
#[repr(u8)]
pub enum Container {
    Mp3 = 0,
    Flac = 1,
    M4a = 2,
    Ogg = 3,
    Wav = 4,
    Aac = 5,
    #[default]
    Unknown = 6,
}

#[derive(Debug, Default)]
pub struct Probed {
    pub container: Container,
    pub duration_us: i64,
    pub track_number: Option<u32>,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub cover: Vec<u8>,
    /// `REPLAYGAIN_TRACK_GAIN` in dB, when tagged.
    pub replay_gain_db: Option<f32>,
}

/// Skips stacked ID3v2 tags and returns where the audio begins.
fn id3v2_end(head: &mut impl FnMut(u64, usize) -> Vec<u8>) -> u64 {
    let mut offset = 0u64;
    for _ in 0..4 {
        let h = head(offset, 10);
        if h.len() < 10 || &h[0..3] != b"ID3" || h[6..10].iter().any(|b| b & 0x80 != 0) {
            break;
        }
        let size = h[6..10].iter().fold(0u64, |a, b| (a << 7) | u64::from(*b));
        offset += 10 + size + if h[5] & 0x10 != 0 { 10 } else { 0 };
    }
    offset
}

fn sniff(head: &mut impl FnMut(u64, usize) -> Vec<u8>) -> Container {
    let offset = id3v2_end(head);
    let h = head(offset, 12);
    if h.len() < 4 {
        return Container::Unknown;
    }
    if h.starts_with(b"fLaC") {
        Container::Flac
    } else if h.starts_with(b"OggS") {
        Container::Ogg
    } else if h.starts_with(b"RIFF") && h.len() >= 12 && &h[8..12] == b"WAVE" {
        Container::Wav
    } else if h.len() >= 8 && &h[4..8] == b"ftyp" {
        Container::M4a
    } else if h[0] == 0xFF && h[1] & 0xF6 == 0xF0 {
        Container::Aac
    } else if h[0] == 0xFF && h[1] & 0xE0 == 0xE0 {
        Container::Mp3
    } else if offset > 0 {
        Container::Mp3
    } else {
        Container::Unknown
    }
}

/// `-6.50 dB` -> -6.5
fn parse_gain(text: &str) -> Option<f32> {
    let trimmed = text
        .trim()
        .trim_end_matches(|c: char| c.is_ascii_alphabetic() || c.is_whitespace());
    trimmed.parse::<f32>().ok().filter(|v| v.is_finite())
}

fn collect(out: &mut Probed, media: &MetadataContainer, front_seen: &mut bool) {
    // Several ARTIST entries (Vorbis comments) read as "A / B"; only the first
    // container that has any decides, so ID3v1 never adds to ID3v2.
    if out.artist.is_empty() {
        let mut artists: Vec<&str> = Vec::new();
        for tag in &media.tags {
            if let Some(StandardTag::Artist(v)) = &tag.std {
                let v = v.trim();
                if !v.is_empty() && !artists.contains(&v) {
                    artists.push(v);
                }
            }
        }
        out.artist = artists.join(" / ");
    }
    for tag in &media.tags {
        match &tag.std {
            Some(StandardTag::TrackTitle(v)) if out.title.is_empty() => {
                out.title = v.trim().to_owned()
            }
            Some(StandardTag::AlbumArtist(v)) if out.artist.is_empty() => {
                out.artist = v.trim().to_owned()
            }
            Some(StandardTag::ReplayGainTrackGain(v)) if out.replay_gain_db.is_none() => {
                out.replay_gain_db = parse_gain(v);
            }
            Some(StandardTag::Album(v)) if out.album.is_empty() => out.album = v.trim().to_owned(),
            Some(StandardTag::TrackNumber(n)) if out.track_number.is_none() && *n > 0 => {
                out.track_number = u32::try_from(*n).ok();
            }
            _ => {}
        }
    }
    for visual in &media.visuals {
        let front = visual.usage == Some(StandardVisualKey::FrontCover);
        let usable = !visual.data.is_empty() && visual.data.len() <= MAX_TAG_BYTES;
        if usable && (out.cover.is_empty() || (front && !*front_seen)) {
            out.cover = visual.data.to_vec();
            *front_seen |= front;
        }
    }
}

fn read_symphonia(source: Box<dyn MediaSource>, ext: &str, out: &mut Probed) {
    let mss = MediaSourceStream::new(source, MediaSourceStreamOptions::default());
    let mut hint = Hint::new();
    if !ext.is_empty() {
        hint.with_extension(ext);
    }
    let meta_opts = MetadataOptions::default()
        .limit_tag_bytes(Limit::Maximum(MAX_TAG_BYTES))
        .limit_visual_bytes(Limit::Maximum(MAX_TAG_BYTES));
    let Ok(mut format) =
        symphonia::default::get_probe().probe(&hint, mss, FormatOptions::default(), meta_opts)
    else {
        return;
    };

    let mut front_seen = false;
    {
        let mut log = format.metadata();
        // `pop` never empties the log, so the newest revision is read in place.
        loop {
            if let Some(rev) = log.current() {
                collect(out, &rev.media, &mut front_seen);
                for per_track in &rev.per_track {
                    collect(out, &per_track.metadata, &mut front_seen);
                }
            }
            if log.pop().is_none() {
                break;
            }
        }
    }
    out.duration_us = duration_us(format.as_mut());
}

fn duration_us(format: &mut dyn FormatReader) -> i64 {
    let Some(track) = format.default_track(TrackType::Audio) else {
        return 0;
    };
    let track_id = track.id;
    let rate = match &track.codec_params {
        Some(CodecParameters::Audio(p)) => p.sample_rate,
        _ => None,
    };
    if let (Some(frames), Some(rate)) = (track.num_frames, rate) {
        return (frames as f64 * 1e6 / f64::from(rate)).round() as i64;
    }
    if let (Some(d), Some(tb)) = (track.duration, track.time_base) {
        if let Some(t) = tb.calc_duration(d) {
            return (t.as_secs_f64() * 1e6).round() as i64;
        }
    }
    // No length in the header (CBR mp3 without a Xing frame): add up the packets.
    let Some(tb) = track.time_base else {
        return 0;
    };
    let mut total = 0u64;
    while let Ok(Some(packet)) = format.next_packet() {
        if packet.track_id == track_id {
            total += packet.dur.get();
        }
    }
    tb.calc_duration(Duration::from(total))
        .map_or(0, |t| (t.as_secs_f64() * 1e6).round() as i64)
}

/// ID3v1 footer, used when the file has no ID3v2 title.
fn apply_id3v1(out: &mut Probed, tail: &[u8]) {
    if tail.len() != 128 || &tail[0..3] != b"TAG" {
        return;
    }
    let field = |at: usize, len: usize| {
        let raw = &tail[at..at + len];
        let end = raw.iter().position(|&c| c == 0).unwrap_or(len);
        raw[..end]
            .iter()
            .map(|&c| char::from(c))
            .collect::<String>()
            .trim()
            .to_owned()
    };
    if out.title.is_empty() {
        out.title = field(3, 30);
    }
    if out.artist.is_empty() {
        out.artist = field(33, 30);
    }
    if out.album.is_empty() {
        out.album = field(63, 30);
    }
    if out.track_number.is_none() && tail[125] == 0 && tail[126] != 0 {
        out.track_number = Some(u32::from(tail[126]));
    }
}

/// Symphonia's WAV reader drops the `LIST/INFO` tags, so read them here.
fn apply_wav_info(read: &mut dyn FnMut(u64, usize) -> Vec<u8>, len: u64, out: &mut Probed) {
    let mut pos = 12u64;
    while pos + 8 <= len {
        let h = read(pos, 8);
        if h.len() < 8 {
            break;
        }
        let size = u64::from(u32::from_le_bytes([h[4], h[5], h[6], h[7]]));
        if &h[0..4] == b"LIST" && size <= 1024 * 1024 {
            let body = read(pos + 8, size as usize);
            if body.starts_with(b"INFO") {
                let mut at = 4usize;
                while at + 8 <= body.len() {
                    let id = &body[at..at + 4];
                    let n = u32::from_le_bytes([
                        body[at + 4],
                        body[at + 5],
                        body[at + 6],
                        body[at + 7],
                    ]) as usize;
                    if at + 8 + n > body.len() {
                        break;
                    }
                    let raw = &body[at + 8..at + 8 + n];
                    let raw = &raw[..raw.iter().position(|&c| c == 0).unwrap_or(raw.len())];
                    let value = String::from_utf8_lossy(raw).trim().to_owned();
                    let slot = match id {
                        b"INAM" => Some(&mut out.title),
                        b"IART" => Some(&mut out.artist),
                        b"IPRD" => Some(&mut out.album),
                        _ => None,
                    };
                    if let Some(slot) = slot {
                        if slot.is_empty() {
                            *slot = value;
                        }
                    }
                    at += 8 + n + (n & 1);
                }
            }
        }
        pos += 8 + size + (size & 1);
    }
}

fn finish(mut out: Probed, container: Container) -> Probed {
    out.container = container;
    out
}

pub fn probe_bytes(data: Vec<u8>, ext: &str) -> Probed {
    let mut reader = |at: u64, len: usize| {
        let start = (at as usize).min(data.len());
        data[start..(start + len).min(data.len())].to_vec()
    };
    let container = sniff(&mut reader);
    let mut out = Probed::default();
    if container != Container::Unknown || ext == "mp3" {
        let tail = data.len().checked_sub(128).map(|s| data[s..].to_vec());
        let total = data.len() as u64;
        if container == Container::Wav {
            apply_wav_info(&mut reader, total, &mut out);
        }
        read_symphonia(Box::new(Cursor::new(data)), ext, &mut out);
        if matches!(container, Container::Mp3 | Container::Unknown) {
            if let Some(tail) = tail {
                apply_id3v1(&mut out, &tail);
            }
        }
    }
    finish(out, container)
}

pub fn probe_file(path: &Path) -> Probed {
    let Ok(mut file) = File::open(path) else {
        return Probed::default();
    };
    let file_len = file.metadata().map(|m| m.len()).unwrap_or(0);
    let mut reader = |at: u64, len: usize| {
        let mut buf = vec![0u8; len];
        if file.seek(SeekFrom::Start(at)).is_err() {
            return Vec::new();
        }
        let mut n = 0;
        while n < len {
            match file.read(&mut buf[n..]) {
                Ok(0) | Err(_) => break,
                Ok(k) => n += k,
            }
        }
        buf.truncate(n);
        buf
    };
    let container = sniff(&mut reader);
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_ascii_lowercase();
    let mut out = Probed::default();
    if container != Container::Unknown || ext == "mp3" {
        let tail = if file_len > 128 {
            Some(reader(file_len - 128, 128))
        } else {
            None
        };
        let Ok(source) = File::open(path) else {
            return finish(out, container);
        };
        if container == Container::Wav {
            apply_wav_info(&mut reader, file_len, &mut out);
        }
        read_symphonia(Box::new(source), &ext, &mut out);
        if matches!(container, Container::Mp3 | Container::Unknown) {
            if let Some(tail) = tail {
                apply_id3v1(&mut out, &tail);
            }
        }
    }
    finish(out, container)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 16-bit mono PCM WAV of `secs` seconds with a LIST/INFO title.
    fn wav(secs: u32, title: &str) -> Vec<u8> {
        let rate = 8000u32;
        let data_len = rate * 2 * secs;
        let mut info = b"INFO".to_vec();
        let mut t = title.as_bytes().to_vec();
        t.push(0);
        if t.len() % 2 == 1 {
            t.push(0);
        }
        info.extend_from_slice(b"INAM");
        info.extend_from_slice(&(t.len() as u32).to_le_bytes());
        info.extend_from_slice(&t);
        let mut out = b"RIFF".to_vec();
        out.extend_from_slice(&(4 + 24 + 8 + info.len() as u32 + 8 + data_len).to_le_bytes());
        out.extend_from_slice(b"WAVEfmt ");
        out.extend_from_slice(&16u32.to_le_bytes());
        for v in [1u16, 1] {
            out.extend_from_slice(&v.to_le_bytes());
        }
        out.extend_from_slice(&rate.to_le_bytes());
        out.extend_from_slice(&(rate * 2).to_le_bytes());
        out.extend_from_slice(&2u16.to_le_bytes());
        out.extend_from_slice(&16u16.to_le_bytes());
        out.extend_from_slice(b"LIST");
        out.extend_from_slice(&(info.len() as u32).to_le_bytes());
        out.extend_from_slice(&info);
        out.extend_from_slice(b"data");
        out.extend_from_slice(&data_len.to_le_bytes());
        out.resize(out.len() + data_len as usize, 0);
        out
    }

    #[test]
    fn wav_duration_and_title() {
        let p = probe_bytes(wav(3, "Rain"), "wav");
        assert_eq!(p.container, Container::Wav);
        assert_eq!(p.duration_us, 3_000_000);
        assert_eq!(p.title, "Rain");
    }

    #[test]
    fn garbage_is_empty_not_an_error() {
        let p = probe_bytes(vec![1, 2, 3, 4, 5, 6, 7, 8], "mp3");
        assert_eq!(p.container, Container::Unknown);
        assert!(p.title.is_empty() && p.duration_us == 0);
        assert_eq!(
            probe_file(Path::new("/definitely/not/here.mp3")).container,
            Container::Unknown
        );
    }

    #[test]
    fn id3v1_footer_fills_the_gaps() {
        let mut tail = vec![0u8; 128];
        tail[..3].copy_from_slice(b"TAG");
        tail[3..8].copy_from_slice(b"Title");
        tail[33..37].copy_from_slice(b"Band");
        tail[126] = 5;
        let mut p = Probed::default();
        apply_id3v1(&mut p, &tail);
        assert_eq!(
            (p.title.as_str(), p.artist.as_str(), p.track_number),
            ("Title", "Band", Some(5))
        );
    }

    #[test]
    fn replay_gain_text_parses() {
        assert_eq!(parse_gain("-6.50 dB"), Some(-6.5));
        assert_eq!(parse_gain("+2.1dB"), Some(2.1));
        assert_eq!(parse_gain("loud"), None);
    }
}

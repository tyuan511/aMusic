//! Seekable HTTP byte source (Range requests) for Symphonia.
//!
//! The Flutter side hands the engine `http://127.0.0.1:port/...` URLs served by
//! `just_audio`'s local proxy, which in turn pulls from the NetEase CDN, so only
//! plain HTTP is needed here. Seeking drops the connection and lazily reopens it
//! with `Range: bytes=pos-`.

use std::io::{self, Read, Seek, SeekFrom};
use std::sync::Mutex;
use std::time::Duration;

use symphonia::core::io::MediaSource;
use ureq::Agent;

type Body = Box<dyn Read + Send>;

pub struct HttpSource {
    agent: Agent,
    url: String,
    len: Option<u64>,
    seekable: bool,
    pos: u64,
    body: Mutex<Option<Body>>,
}

impl HttpSource {
    pub fn open(url: &str) -> io::Result<Self> {
        let agent: Agent = Agent::config_builder()
            .http_status_as_error(false)
            .timeout_connect(Some(Duration::from_secs(10)))
            .timeout_recv_response(Some(Duration::from_secs(20)))
            .timeout_per_read(Some(Duration::from_secs(20)))
            .build()
            .into();
        let mut src = Self {
            agent,
            url: url.to_string(),
            len: None,
            seekable: false,
            pos: 0,
            body: Mutex::new(None),
        };
        let (body, len, seekable) = src.request(0)?;
        src.len = len;
        src.seekable = seekable;
        *src.body.lock().unwrap() = Some(body);
        Ok(src)
    }

    /// Opens a connection at `pos`; returns the body, total length and whether
    /// the server honours ranges.
    fn request(&self, pos: u64) -> io::Result<(Body, Option<u64>, bool)> {
        let resp = self
            .agent
            .get(&self.url)
            .header("Range", &format!("bytes={pos}-"))
            .call()
            .map_err(io::Error::other)?;
        let status = resp.status().as_u16();
        let header = |name: &str| {
            resp.headers().get(name).and_then(|v| v.to_str().ok()).map(str::to_owned)
        };
        let (len, seekable) = match status {
            206 => {
                // Content-Range: bytes 100-999/1000
                let total = header("content-range")
                    .and_then(|v| v.rsplit('/').next().and_then(|t| t.trim().parse().ok()));
                (total, true)
            }
            200 => {
                let total = header("content-length").and_then(|v| v.trim().parse().ok());
                (total, false)
            }
            416 => return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "range not satisfiable")),
            code => return Err(io::Error::other(format!("http status {code}"))),
        };
        if pos > 0 && status == 200 {
            return Err(io::Error::other("server ignored the range request"));
        }
        Ok((Box::new(resp.into_body().into_reader()), len, seekable))
    }
}

impl Read for HttpSource {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        if buf.is_empty() {
            return Ok(0);
        }
        if let Some(len) = self.len {
            if self.pos >= len {
                return Ok(0);
            }
        }
        if self.body.get_mut().unwrap().is_none() {
            let (body, _, _) = self.request(self.pos)?;
            *self.body.get_mut().unwrap() = Some(body);
        }
        let n = self.body.get_mut().unwrap().as_mut().unwrap().read(buf)?;
        self.pos += n as u64;
        Ok(n)
    }
}

impl Seek for HttpSource {
    fn seek(&mut self, to: SeekFrom) -> io::Result<u64> {
        let target = match to {
            SeekFrom::Start(p) => p as i128,
            SeekFrom::Current(d) => self.pos as i128 + d as i128,
            SeekFrom::End(d) => {
                let len = self.len.ok_or_else(|| io::Error::other("unknown length"))?;
                len as i128 + d as i128
            }
        };
        if target < 0 {
            return Err(io::Error::new(io::ErrorKind::InvalidInput, "negative seek"));
        }
        let target = target as u64;
        if target != self.pos {
            if !self.seekable {
                return Err(io::Error::other("source is not seekable"));
            }
            // Reopen lazily on the next read.
            *self.body.get_mut().unwrap() = None;
            self.pos = target;
        }
        Ok(self.pos)
    }
}

impl MediaSource for HttpSource {
    fn is_seekable(&self) -> bool {
        self.seekable && self.len.is_some()
    }

    fn byte_len(&self) -> Option<u64> {
        self.len
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::net::TcpListener;
    use std::thread;

    /// A tiny range-capable HTTP server for the tests.
    fn serve(data: Vec<u8>, ranges: bool) -> String {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap();
        thread::spawn(move || {
            for stream in listener.incoming() {
                let Ok(mut stream) = stream else { continue };
                let data = data.clone();
                thread::spawn(move || {
                    let mut buf = [0u8; 2048];
                    let n = stream.read(&mut buf).unwrap_or(0);
                    let req = String::from_utf8_lossy(&buf[..n]).to_string();
                    let start = req
                        .lines()
                        .find_map(|l| l.to_ascii_lowercase().strip_prefix("range: bytes=").map(str::to_owned))
                        .and_then(|r| r.trim_end_matches('-').split('-').next().and_then(|s| s.parse::<usize>().ok()))
                        .unwrap_or(0);
                    let head = if ranges && start > 0 || ranges && req.to_lowercase().contains("range:") {
                        format!(
                            "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes {start}-{}/{}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                            data.len() - 1,
                            data.len(),
                            data.len() - start
                        )
                    } else {
                        format!("HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n", data.len())
                    };
                    let from = if ranges { start } else { 0 };
                    let _ = stream.write_all(head.as_bytes());
                    let _ = stream.write_all(&data[from..]);
                });
            }
        });
        format!("http://{addr}/track.bin")
    }

    #[test]
    fn reads_and_seeks_with_ranges() {
        let data: Vec<u8> = (0..50_000u32).map(|i| (i % 251) as u8).collect();
        let url = serve(data.clone(), true);
        let mut src = HttpSource::open(&url).unwrap();
        assert!(src.is_seekable());
        assert_eq!(src.byte_len(), Some(50_000));

        let mut head = [0u8; 100];
        src.read_exact(&mut head).unwrap();
        assert_eq!(&head[..], &data[..100]);

        src.seek(SeekFrom::Start(30_000)).unwrap();
        let mut mid = [0u8; 64];
        src.read_exact(&mut mid).unwrap();
        assert_eq!(&mid[..], &data[30_000..30_064]);

        src.seek(SeekFrom::End(-10)).unwrap();
        let mut tail = Vec::new();
        src.read_to_end(&mut tail).unwrap();
        assert_eq!(tail, &data[49_990..]);
        assert_eq!(src.read(&mut [0u8; 4]).unwrap(), 0);
    }

    #[test]
    fn server_without_ranges_is_not_seekable() {
        let data = vec![7u8; 4096];
        let url = serve(data, false);
        let mut src = HttpSource::open(&url).unwrap();
        assert!(!src.is_seekable());
        assert!(src.seek(SeekFrom::Start(100)).is_err());
        let mut all = Vec::new();
        src.read_to_end(&mut all).unwrap();
        assert_eq!(all.len(), 4096);
    }

    #[test]
    fn refused_connection_is_an_error() {
        assert!(HttpSource::open("http://127.0.0.1:1/nothing").is_err());
    }
}

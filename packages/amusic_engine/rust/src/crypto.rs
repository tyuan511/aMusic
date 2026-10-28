//! NetEase Cloud Music request encryption (`eapi` and `weapi`).

use aes::cipher::block_padding::Pkcs7;
use aes::cipher::{BlockEncryptMut, KeyInit, KeyIvInit};
use md5::{Digest, Md5};
use num_bigint::BigUint;

const PRESET_KEY: &[u8; 16] = b"0CoJUm6Qyw8W8jud";
const IV: &[u8; 16] = b"0102030405060708";
const EAPI_KEY: &[u8; 16] = b"e82ckenh8dichen8";
const EAPI_SEPARATOR: &str = "-36cd479b6b5-";

/// Modulus of the RSA-1024 public key used by weapi (exponent 65537).
const MODULUS_HEX: &str = "e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7";

fn hex_upper(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02X}")).collect()
}

/// `url-36cd479b6b5-{json}-36cd479b6b5-{md5}` under AES-128-ECB, upper case hex.
pub fn eapi(uri: &str, json: &str) -> String {
    let digest = Md5::digest(format!("nobody{uri}use{json}md5forencrypt"));
    let md5_hex: String = digest.iter().map(|b| format!("{b:02x}")).collect();
    let payload = format!("{uri}{EAPI_SEPARATOR}{json}{EAPI_SEPARATOR}{md5_hex}");
    let cipher = ecb::Encryptor::<aes::Aes128>::new(EAPI_KEY.into());
    hex_upper(&cipher.encrypt_padded_vec_mut::<Pkcs7>(payload.as_bytes()))
}

fn aes_cbc_base64(plain: &[u8], key: &[u8; 16]) -> String {
    let cipher = cbc::Encryptor::<aes::Aes128>::new(key.into(), IV.into());
    base64(&cipher.encrypt_padded_vec_mut::<Pkcs7>(plain))
}

fn base64(data: &[u8]) -> String {
    const T: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity(data.len().div_ceil(3) * 4);
    for chunk in data.chunks(3) {
        let n = (chunk[0] as u32) << 16
            | (*chunk.get(1).unwrap_or(&0) as u32) << 8
            | *chunk.get(2).unwrap_or(&0) as u32;
        out.push(T[(n >> 18) as usize & 63] as char);
        out.push(T[(n >> 12) as usize & 63] as char);
        out.push(if chunk.len() > 1 {
            T[(n >> 6) as usize & 63] as char
        } else {
            '='
        });
        out.push(if chunk.len() > 2 {
            T[n as usize & 63] as char
        } else {
            '='
        });
    }
    out
}

/// Raw RSA (no padding) of the reversed key, left padded to the modulus size.
fn rsa_hex(key: &[u8; 16]) -> String {
    let modulus = BigUint::parse_bytes(MODULUS_HEX.as_bytes(), 16).expect("modulus");
    let reversed: Vec<u8> = key.iter().rev().copied().collect();
    let encrypted = BigUint::from_bytes_be(&reversed).modpow(&BigUint::from(65537u32), &modulus);
    let width = (modulus.bits() as usize).div_ceil(8) * 2;
    format!("{:0>width$}", encrypted.to_str_radix(16))
}

/// `(params, encSecKey)` for the web API; `secret` is a 16 character key.
pub fn weapi(json: &str, secret: &[u8; 16]) -> (String, String) {
    let first = aes_cbc_base64(json.as_bytes(), PRESET_KEY);
    (aes_cbc_base64(first.as_bytes(), secret), rsa_hex(secret))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn eapi_is_upper_hex_block_aligned() {
        let out = eapi("/api/x", "{\"a\":1}");
        assert_eq!(out.len() % 32, 0);
        assert!(out
            .chars()
            .all(|c| c.is_ascii_digit() || ('A'..='F').contains(&c)));
    }

    #[test]
    fn weapi_key_is_modulus_wide() {
        let (params, sec) = weapi("{}", b"abcdefghijklmnop");
        assert_eq!(sec.len(), 256);
        assert!(!params.is_empty());
    }
}

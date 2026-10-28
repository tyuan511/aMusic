import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:amusic_engine/amusic_engine.dart';

/// NetEase Cloud Music request encryption.
///
/// Two schemes are used by the official clients:
///
/// * **eapi** – `AES-128-ECB` over `url-text-md5` with a fixed key. Used by the
///   desktop/mobile clients (`interfacepc.music.163.com`).
/// * **weapi** – double `AES-128-CBC` plus `RSA` for the key. Used by the web
///   player (`music.163.com`) for endpoints such as `login/status`.
///
/// The cipher work happens in the Rust engine; this class only draws the
/// randomness and shapes the payload.
class NeteaseCrypto {
  NeteaseCrypto._();

  static final Random _random = Random.secure();
  static const String _base62 =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  /// `eapi` payload: `url-36cd479b6b5-{json}-36cd479b6b5-{md5}` encrypted with
  /// AES-128-ECB, hex encoded (upper case, as the official client sends it).
  static String eapi(String uri, Map<String, dynamic> data) =>
      AmusicTools.instance.eapi(uri, jsonEncode(data));

  /// `weapi` payload: `{params, encSecKey}`.
  static ({String params, String encSecKey}) weapi(Map<String, dynamic> data) {
    final secret = Uint8List.fromList(
      utf8.encode(_randomKey(16)),
    );
    return AmusicTools.instance.weapi(jsonEncode(data), secret);
  }

  static String _randomKey(int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_base62[_random.nextInt(_base62.length)]);
    }
    return buffer.toString();
  }

  /// Random bytes as lower case hex, used for the device identifiers.
  static String randomHex(int byteLength) {
    final buffer = StringBuffer();
    for (var i = 0; i < byteLength; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static String randomLetters(int length) {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(letters[_random.nextInt(letters.length)]);
    }
    return buffer.toString();
  }
}

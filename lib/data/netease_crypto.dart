import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// NetEase Cloud Music request encryption.
///
/// Two schemes are used by the official clients:
///
/// * **eapi** – `AES-128-ECB` over `url-text-md5` with a fixed key. Used by the
///   desktop/mobile clients (`interfacepc.music.163.com`).
/// * **weapi** – double `AES-128-CBC` plus `RSA` for the key. Used by the web
///   player (`music.163.com`) for endpoints such as `login/status`.
///
/// Both are implemented here so the app can talk to NetEase directly instead of
/// going through a self hosted Node server.
class NeteaseCrypto {
  NeteaseCrypto._();

  static const String _presetKey = '0CoJUm6Qyw8W8jud';
  static const String _iv = '0102030405060708';
  static const String _eapiKey = 'e82ckenh8dichen8';

  static const String _eapiSeparator = '-36cd479b6b5-';

  static final Random _random = Random.secure();
  static const String _base62 =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  /// `eapi` payload: `url-36cd479b6b5-{json}-36cd479b6b5-{md5}` encrypted with
  /// AES-128-ECB, hex encoded (upper case, as the official client sends it).
  static String eapi(String uri, Map<String, dynamic> data) {
    final text = jsonEncode(data);
    final digest = md5.convert(
      utf8.encode('nobody$uri${'use'}$text${'md5forencrypt'}'),
    );
    final payload = '$uri$_eapiSeparator$text$_eapiSeparator$digest';
    return _aesEcbHex(payload, _eapiKey);
  }

  /// `weapi` payload: `{params, encSecKey}`.
  static ({String params, String encSecKey}) weapi(Map<String, dynamic> data) {
    final text = jsonEncode(data);
    final secretKey = _randomKey(16);
    final first = _aesCbcBase64(text, _presetKey);
    final params = _aesCbcBase64(first, secretKey);
    final reversedKey = secretKey.split('').reversed.join();
    return (params: params, encSecKey: _rsaEncryptHex(reversedKey));
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

  // ------------------------------------------------------------------- AES

  static String _aesCbcBase64(String plainText, String key) {
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
              ParametersWithIV<KeyParameter>(
                KeyParameter(utf8.encode(key)),
                utf8.encode(_iv),
              ),
              null,
            ),
          );
    final output = cipher.process(Uint8List.fromList(utf8.encode(plainText)));
    return base64.encode(output);
  }

  static String _aesEcbHex(String plainText, String key) {
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
              KeyParameter(utf8.encode(key)),
              null,
            ),
          );
    final output = cipher.process(Uint8List.fromList(utf8.encode(plainText)));
    return output
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  // ------------------------------------------------------------------- RSA

  /// Modulus of the public key used by weapi (RSA-1024). Kept as a literal so
  /// there is no DER/PEM parsing to get wrong.
  static final BigInt _modulus = BigInt.parse(
    'e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e'
    '417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee2559'
    '32575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7',
    radix: 16,
  );
  static final BigInt _exponent = BigInt.from(65537);

  static String _rsaEncryptHex(String plainText) {
    // Raw RSA (no padding), matching the official client. The ciphertext is
    // always the modulus size, so leading zero bytes have to be preserved.
    final message = _bytesToBigInt(Uint8List.fromList(utf8.encode(plainText)));
    final encrypted = message.modPow(_exponent, _modulus);
    final modulusBytes = (_modulus.bitLength + 7) >> 3;
    return encrypted.toRadixString(16).padLeft(modulusBytes * 2, '0');
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value;
  }
}

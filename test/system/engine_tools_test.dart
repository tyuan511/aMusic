import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:amusic/data/netease_crypto.dart';
import 'package:amusic_engine/amusic_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('eapi is upper case hex in whole AES blocks', () {
    final out = NeteaseCrypto.eapi('/api/song/lyric', {'id': 1, 'name': '晴天'});
    expect(out.length % 32, 0);
    expect(RegExp(r'^[0-9A-F]+$').hasMatch(out), isTrue);
  });

  test('weapi gives params and a modulus wide encSecKey', () {
    final payload = NeteaseCrypto.weapi({'csrf_token': ''});
    expect(payload.params, isNotEmpty);
    expect(payload.encSecKey, hasLength(256));
  });

  test('weapi is deterministic for a given secret', () {
    final secret = Uint8List.fromList(utf8.encode('aB3dE5gH7jK9mN1p'));
    final a = AmusicTools.instance.weapi('{}', secret);
    final b = AmusicTools.instance.weapi('{}', secret);
    expect(a.params, b.params);
    expect(a.encSecKey, b.encSecKey);
  });

  test('cover palette finds the colour of a red picture', () async {
    final bytes = File('test/system/data/cover.jpg').readAsBytesSync();
    final swatches = await AmusicTools.coverPaletteAsync(bytes);
    expect(swatches, isNotNull);
    final vibrant = swatches!.vibrant;
    expect(vibrant, isNot(0));
    expect((vibrant >> 16) & 0xFF, greaterThan(180)); // red channel
    expect((vibrant >> 8) & 0xFF, lessThan(80));
  });

  test('an undecodable cover gives null instead of throwing', () async {
    expect(
      await AmusicTools.coverPaletteAsync(Uint8List.fromList([1, 2, 3])),
      isNull,
    );
  });

  test('spectrum analysis returns a normalised timeline envelope', () async {
    final values = await AmusicTools.spectrumFileAsync(
      'test/system/data/song.flac',
      bands: 48,
    );
    expect(values, isNotNull);
    expect(values, hasLength(48));
    expect(values!.any((value) => value > 0), isTrue);
    expect(values.toSet().length, greaterThan(1));
  });
}

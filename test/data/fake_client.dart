import 'dart:async';

import 'package:amusic/data/netease_client.dart';

typedef FakeHandler = FutureOr<Map<String, dynamic>> Function(
  String uri,
  Map<String, dynamic> data,
  CryptoMode crypto,
);

/// In-memory stand-in for the encrypted HTTP client.
class FakeNeteaseClient implements NeteaseClient {
  FakeNeteaseClient(this.handler, {NeteaseCookies? cookies})
    : cookies = cookies ?? NeteaseCookies();

  final FakeHandler handler;
  final List<({String uri, Map<String, dynamic> data, CryptoMode crypto})>
  calls = [];

  @override
  final DeviceProfile device = DeviceProfile.generate();

  @override
  final NeteaseCookies cookies;

  @override
  Future<Map<String, dynamic>> request(
    String uri,
    Map<String, dynamic> data, {
    CryptoMode crypto = CryptoMode.eapi,
  }) async {
    calls.add((uri: uri, data: data, crypto: crypto));
    return handler(uri, data, crypto);
  }

  Iterable<String> get uris => calls.map((call) => call.uri);
}

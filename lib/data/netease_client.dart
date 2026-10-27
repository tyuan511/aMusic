import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../core/errors.dart';
import 'netease_crypto.dart';

/// Which encryption scheme an endpoint expects.
enum CryptoMode {
  /// Official desktop/mobile client scheme, most endpoints accept it.
  eapi('https://interfacepc.music.163.com', '/eapi/'),

  /// Web player scheme, required by a few endpoints such as `login/status`.
  weapi('https://music.163.com', '/weapi/');

  const CryptoMode(this.host, this.pathPrefix);

  final String host;
  final String pathPrefix;
}

/// Persistent device identity. NetEase ties anonymous requests to it, so it is
/// generated once and stored with the preferences.
class DeviceProfile {
  DeviceProfile({
    required this.deviceId,
    required this.nuid,
    required this.nnid,
    required this.wnmcid,
    required this.buildver,
    this.os = 'pc',
    this.osver = 'Microsoft-Windows-10-Professional-build-19045-64bit',
    this.appver = '3.1.17.204416',
    this.channel = 'netease',
    this.versioncode = '140',
    this.resolution = '1920x1080',
    this.mobilename = '',
  });

  final String deviceId;
  final String nuid;
  final String nnid;
  final String wnmcid;
  final String buildver;
  final String os;
  final String osver;
  final String appver;
  final String channel;
  final String versioncode;
  final String resolution;
  final String mobilename;

  static final Random _random = Random();

  factory DeviceProfile.generate() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final nuid = NeteaseCrypto.randomHex(16);
    return DeviceProfile(
      // 32 hex chars, same shape as the official client's device id.
      deviceId: NeteaseCrypto.randomHex(16).toUpperCase(),
      nuid: nuid,
      nnid: '$nuid,$now',
      wnmcid: '${NeteaseCrypto.randomLetters(6)}.$now.01.0',
      buildver: now.toString().substring(0, 10),
    );
  }

  factory DeviceProfile.fromJson(Map<String, dynamic> json) => DeviceProfile(
    deviceId: json['deviceId'] as String,
    nuid: json['nuid'] as String,
    nnid: json['nnid'] as String,
    wnmcid: json['wnmcid'] as String,
    buildver: json['buildver'] as String,
    os: json['os'] as String? ?? 'pc',
    osver:
        json['osver'] as String? ??
        'Microsoft-Windows-10-Professional-build-19045-64bit',
    appver: json['appver'] as String? ?? '3.1.17.204416',
    channel: json['channel'] as String? ?? 'netease',
    versioncode: json['versioncode'] as String? ?? '140',
    resolution: json['resolution'] as String? ?? '1920x1080',
    mobilename: json['mobilename'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'nuid': nuid,
    'nnid': nnid,
    'wnmcid': wnmcid,
    'buildver': buildver,
    'os': os,
    'osver': osver,
    'appver': appver,
    'channel': channel,
    'versioncode': versioncode,
    'resolution': resolution,
    'mobilename': mobilename,
  };

  String get requestId =>
      '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000).toString().padLeft(4, '0')}';
}

/// Cookie jar for the NetEase session.
///
/// The API answers with `set-cookie`; `MUSIC_U` inside it is the login token.
class NeteaseCookies {
  final Map<String, String> _values = {};

  void Function()? onChange;

  String? get musicU => _values['MUSIC_U'];

  String? get csrf => _values['__csrf'];

  bool get isLoggedIn => (_values['MUSIC_U'] ?? '').isNotEmpty;

  bool get hasAny => _values.isNotEmpty;

  Map<String, String> get all => Map.unmodifiable(_values);

  void absorb(List<String>? setCookies) {
    if (setCookies == null || setCookies.isEmpty) return;
    var changed = false;
    for (final entry in setCookies) {
      final first = entry.split(';').first.trim();
      final index = first.indexOf('=');
      if (index <= 0) continue;
      final key = first.substring(0, index).trim();
      final value = first.substring(index + 1).trim();
      if (key.isEmpty) continue;
      if (value.isEmpty || value == 'deleteMe') {
        if (_values.remove(key) != null) changed = true;
      } else if (_values[key] != value) {
        _values[key] = value;
        changed = true;
      }
    }
    if (changed) onChange?.call();
  }

  void load(Map<String, dynamic> json) {
    for (final entry in json.entries) {
      final value = entry.value;
      if (value is String && value.isNotEmpty) _values[entry.key] = value;
    }
  }

  void clear() {
    _values.clear();
    onChange?.call();
  }

  /// Copy of every cookie, for [restore] after a failed login attempt.
  Map<String, String> snapshot() => Map.of(_values);

  /// Replaces the whole jar with [values] (one change notification).
  void restore(Map<String, String> values) {
    _values
      ..clear()
      ..addAll({
        for (final entry in values.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
      });
    onChange?.call();
  }

  /// Removes one cookie.
  void remove(String key) {
    if (_values.remove(key) != null) onChange?.call();
  }

  static const Set<String> _attributeNames = {
    'path',
    'domain',
    'expires',
    'max-age',
    'httponly',
    'secure',
    'samesite',
    'priority',
    'version',
  };

  /// Parses user supplied cookie text: `MUSIC_U=...; __csrf=...`, a full
  /// `Cookie:` header, several `set-cookie` lines, or a bare `MUSIC_U` token.
  /// Cookie attributes (`Path`, `Expires`...) are ignored, values are
  /// percent-decoded when they were encoded.
  static Map<String, String> parse(String raw) {
    final prefix = RegExp(r'^(set-)?cookie:\s*', caseSensitive: false);
    final result = <String, String>{};
    for (final part in raw.split(RegExp(r'[;\n\r]'))) {
      final item = part.trim().replaceFirst(prefix, '');
      if (item.isEmpty) continue;
      final index = item.indexOf('=');
      if (index < 0) {
        // A bare token is the MUSIC_U value itself.
        if (!_attributeNames.contains(item.toLowerCase()) &&
            item.length > 32 &&
            !item.contains(' ')) {
          result['MUSIC_U'] = item;
        }
        continue;
      }
      if (index == 0) continue;
      final key = item.substring(0, index).trim();
      var value = item.substring(index + 1).trim();
      if (_attributeNames.contains(key.toLowerCase())) continue;
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      try {
        value = Uri.decodeComponent(value);
      } on ArgumentError {
        // Not percent encoded, keep as is.
      }
      if (key.isEmpty || value.isEmpty) continue;
      result[key] = value;
    }
    return result;
  }

  /// `k=v; k=v`, values percent encoded like the official client.
  String encode(Map<String, String> values) => values.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('; ');
}

/// Direct HTTP client for the NetEase Cloud Music API.
///
/// Requests are encrypted on device ([NeteaseCrypto]) and sent to the official
/// hosts, so no self hosted server or extra port is involved.
class NeteaseClient {
  NeteaseClient({required this.device, required this.cookies}) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 15),
        followRedirects: true,
        maxRedirects: 3,
        responseType: ResponseType.plain,
        // NetEase answers 200 with a business code inside the body; 4xx/5xx are
        // real transport problems.
        validateStatus: (status) => status != null && status < 500,
        headers: {'Accept': '*/*', 'Accept-Encoding': 'gzip'},
      ),
    );
  }

  final DeviceProfile device;
  final NeteaseCookies cookies;
  late final Dio _dio;

  static const String _eapiUa =
      'NeteaseMusic/9.1.65.240927161425(9001065);Dalvik/2.1.0 (Linux; U; Android 14; Pixel 7 Build/UQ1A.240105.004)';
  static const String _weapiUa =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  /// Sends [data] to [uri] (an `/api/...` path) and returns the decoded body.
  Future<Map<String, dynamic>> request(
    String uri,
    Map<String, dynamic> data, {
    CryptoMode crypto = CryptoMode.eapi,
  }) async {
    final payload = Map<String, dynamic>.from(data);
    // Response payloads stay plain text, which keeps parsing simple.
    payload['e_r'] = false;

    final Response<String> response;
    try {
      response = switch (crypto) {
        CryptoMode.eapi => await _postEapi(uri, payload),
        CryptoMode.weapi => await _postWeapi(uri, payload),
      };
    } on DioException catch (error) {
      throw _translate(error);
    }

    cookies.absorb(response.headers.map['set-cookie']);
    return _decode(response.data, response.statusCode);
  }

  Future<Response<String>> _postEapi(String uri, Map<String, dynamic> data) {
    final header = <String, String>{
      'osver': device.osver,
      'deviceId': device.deviceId,
      'os': device.os,
      'appver': device.appver,
      'versioncode': device.versioncode,
      'mobilename': device.mobilename,
      'buildver': device.buildver,
      'resolution': device.resolution,
      '__csrf': cookies.csrf ?? '',
      'channel': device.channel,
      'requestId': device.requestId,
    };
    final musicU = cookies.musicU;
    if (musicU != null && musicU.isNotEmpty) header['MUSIC_U'] = musicU;
    final nmtid = cookies.all['NMTID'];
    if (nmtid != null && nmtid.isNotEmpty) header['NMTID'] = nmtid;

    data['header'] = header;
    final params = NeteaseCrypto.eapi(uri, data);
    return _dio.post<String>(
      '${CryptoMode.eapi.host}${CryptoMode.eapi.pathPrefix}${_stripPrefix(uri)}',
      data: 'params=$params',
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'User-Agent': _eapiUa,
          'Cookie': _cookieHeader(header),
          'X-Real-IP': '1.1.1.1',
          'X-Forwarded-For': '1.1.1.1',
        },
      ),
    );
  }

  Future<Response<String>> _postWeapi(String uri, Map<String, dynamic> data) {
    data['csrf_token'] = cookies.csrf ?? '';
    final encrypted = NeteaseCrypto.weapi(data);
    return _dio.post<String>(
      '${CryptoMode.weapi.host}${CryptoMode.weapi.pathPrefix}${_stripPrefix(uri)}',
      data:
          'params=${Uri.encodeQueryComponent(encrypted.params)}'
          '&encSecKey=${Uri.encodeQueryComponent(encrypted.encSecKey)}',
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'User-Agent': _weapiUa,
          'Referer': 'https://music.163.com',
          'Origin': 'https://music.163.com',
          'Cookie': _cookieHeader({
            'NMTID': '00O${NeteaseCrypto.randomHex(19)}',
            '_ntes_nuid': device.nuid,
            '_ntes_nnid': device.nnid,
            'WNMCID': device.wnmcid,
            if (cookies.musicU != null) 'MUSIC_U': cookies.musicU!,
          }),
        },
      ),
    );
  }

  String _cookieHeader(Map<String, String> values) => values.entries
      .where((entry) => entry.value.isNotEmpty)
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
      )
      .join('; ');

  /// `/api/x/y` -> `x/y`
  static String _stripPrefix(String uri) => uri.startsWith('/api/')
      ? uri.substring(5)
      : (uri.startsWith('/') ? uri.substring(1) : uri);

  Map<String, dynamic> _decode(String? body, int? status) {
    if (body == null || body.trim().isEmpty) {
      throw ApiException(status, '服务器返回空响应');
    }
    final text = body.trim();
    // Some error responses repeat the same document back to back.
    final boundary = text.indexOf('}{');
    final candidate = boundary > 0 ? text.substring(0, boundary + 1) : text;
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Fall through to the error below.
    }
    throw ApiException(status, '返回数据无法解析');
  }

  AppException _translate(DioException error) {
    final type = error.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return const ServerUnreachableException('网络连接超时，请检查网络');
    }
    if (type == DioExceptionType.connectionError) {
      return const ServerUnreachableException('无法连接网易云音乐服务器');
    }
    if (type == DioExceptionType.cancel) {
      return const ServerUnreachableException('请求已取消');
    }
    // 5xx, TLS problems and unknown socket errors: the transport is broken,
    // retrying a variant of the same request would fail the same way.
    final status = error.response?.statusCode;
    return ServerUnreachableException(
      status != null ? '网易云服务器异常 ($status)' : '网络请求失败，请检查网络',
    );
  }
}

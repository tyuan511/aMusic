import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import '../data/ncm_api.dart';
import '../data/netease_client.dart';

/// Owns the encrypted HTTP client, the device identity and the session cookie.
///
/// Everything lives in the app: there is no self hosted server and no extra
/// port, requests go straight to the official NetEase hosts.
class ApiHost {
  ApiHost({required SharedPreferences prefs}) : _prefs = prefs {
    _device = _loadDevice(prefs);
    _cookies = NeteaseCookies()..load(_loadCookies(prefs));
    _cookies.onChange = _persistCookies;
    _client = NeteaseClient(device: _device, cookies: _cookies);
    api = NcmApi(_client);
  }

  final SharedPreferences _prefs;
  late final DeviceProfile _device;
  late final NeteaseCookies _cookies;
  late final NeteaseClient _client;
  late NcmApi api;

  DeviceProfile get device => _device;

  /// Forwarded to [NcmApi.onSessionExpired]: an authenticated request was
  /// answered with 301. Owned by the session service.
  set onSessionExpired(void Function()? callback) =>
      api.onSessionExpired = callback;

  NeteaseCookies get cookies => _cookies;

  bool get isLoggedIn => _cookies.isLoggedIn;

  static DeviceProfile _loadDevice(SharedPreferences prefs) {
    final raw = prefs.getString(PrefsKeys.deviceProfile);
    if (raw != null) {
      try {
        return DeviceProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } on Object {
        // Regenerate below.
      }
    }
    final device = DeviceProfile.generate();
    prefs.setString(PrefsKeys.deviceProfile, jsonEncode(device.toJson()));
    return device;
  }

  Map<String, dynamic> _loadCookies(SharedPreferences prefs) {
    final raw = _prefs.getString(PrefsKeys.cookie);
    if (raw == null || raw.trim().isEmpty) return const {};
    final text = raw.trim();
    // Current format: a JSON object. Older builds stored the raw header text
    // (`MUSIC_U=...; __csrf=...`), which still has to be honoured so users do
    // not have to scan the QR code again.
    if (text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
      } on Object {
        return const {};
      }
    }
    return NeteaseCookies.parse(text);
  }

  void _persistCookies() {
    final values = _cookies.all;
    if (values.isEmpty) {
      _prefs.remove(PrefsKeys.cookie);
    } else {
      _prefs.setString(PrefsKeys.cookie, jsonEncode(values));
    }
  }

  /// Cheap connectivity probe used by the settings screen.
  Future<bool> ping() async {
    try {
      await api.loginStatus();
      return true;
    } on Object {
      return false;
    }
  }

  void dispose() => _cookies.onChange = null;
}

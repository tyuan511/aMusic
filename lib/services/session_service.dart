import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../data/ncm_api.dart';
import '../data/netease_client.dart';
import '../models/playlist.dart';
import 'api_host.dart';

enum QrPhase { idle, loading, waiting, scanned, success, expired, error }

class QrLoginTicket {
  const QrLoginTicket({required this.phase, this.key, this.message});

  final QrPhase phase;
  final String? key;
  final String? message;

  /// Content of the QR code, `null` until a key arrives.
  String? get url =>
      key == null ? null : 'https://music.163.com/login?codekey=$key';

  QrLoginTicket copyWith({QrPhase? phase, String? key, String? message}) =>
      QrLoginTicket(
        phase: phase ?? this.phase,
        key: key ?? this.key,
        message: message,
      );
}

class SessionState {
  const SessionState({this.profile, this.loading = false, this.error});

  final UserProfile? profile;
  final bool loading;
  final String? error;

  bool get isLoggedIn => profile != null;

  SessionState copyWith({
    UserProfile? profile,
    bool? loading,
    String? error,
    bool clear = false,
  }) => SessionState(
    profile: clear ? null : (profile ?? this.profile),
    loading: loading ?? this.loading,
    error: error,
  );
}

/// Login state, the QR login state machine and the SMS / password / cookie
/// sign in flows.
///
/// Every successful sign in / sign out bumps [authRevision]. A failed attempt
/// never touches the current session: cookies are rolled back.
class SessionService extends ValueNotifier<SessionState> {
  SessionService(this._host) : super(const SessionState()) {
    _host.onSessionExpired = _onSessionExpired;
  }

  final ApiHost _host;

  /// Notifies go_router that the user signed in or out.
  final ValueNotifier<int> authRevision = ValueNotifier(0);

  Timer? _pollTimer;
  Completer<bool>? _loginCompleter;
  bool _checkingExpiry = false;

  /// Restores a persisted session. Never throws: a dead server just means
  /// "not logged in yet", the cookie is kept for later. A cookie the server
  /// definitely rejects (account endpoint answers "no profile") is dropped.
  /// On success the token is refreshed silently in the background.
  Future<void> restore() async {
    if (!_host.cookies.hasAny) {
      value = const SessionState();
      return;
    }
    value = value.copyWith(loading: true);
    try {
      var profile = await _host.api.loginStatus();
      if (profile == null && _host.cookies.isLoggedIn) {
        // One retry before dropping a token: the account endpoint can lag.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        profile = await _host.api.loginStatus();
      }
      if (profile == null && _host.cookies.isLoggedIn) {
        // MUSIC_U is present but no longer accepted.
        _host.cookies.remove('MUSIC_U');
        value = const SessionState(error: '登录已失效，请重新登录');
      } else {
        value = SessionState(profile: profile);
      }
      if (profile != null) unawaited(refreshToken());
    } on AppException catch (error) {
      value = SessionState(error: error.message);
    } finally {
      authRevision.value++;
    }
  }

  /// True when signed in. A saved cookie without a loaded profile (the
  /// start-up check failed on a flaky network) is re-checked once here.
  Future<bool> ensureSignedIn() async {
    if (value.isLoggedIn) return true;
    if (!_host.cookies.isLoggedIn || value.loading) return false;
    await restore();
    return value.isLoggedIn;
  }

  /// Extends the `MUSIC_U` lifetime. Silent: failures are ignored, a really
  /// expired session is detected by the next 301.
  Future<bool> refreshToken() async {
    if (!_host.cookies.isLoggedIn) return false;
    try {
      await _host.api.refreshToken();
      return true;
    } on AppException {
      return false;
    }
  }

  /// An authenticated request answered 301: re-check the account and sign
  /// out locally when the session is really gone.
  Future<void> _onSessionExpired() async {
    if (_checkingExpiry || !value.isLoggedIn) return;
    _checkingExpiry = true;
    try {
      final profile = await _host.api.loginStatus();
      if (profile == null) {
        _host.cookies.remove('MUSIC_U');
        value = const SessionState(error: '登录已失效，请重新登录');
        authRevision.value++;
      }
    } on AppException {
      // Network trouble: keep the session, the next call will tell.
    } finally {
      _checkingExpiry = false;
    }
  }

  // ------------------------------------------------------ phone sign in

  /// Sends an SMS code to [phone]. Throws [AppException] with a short
  /// Chinese message (invalid number, rate limited, risk control...).
  Future<void> sendSmsCode(String phone, {int countryCode = 86}) {
    _checkPhone(phone);
    return _host.api.sendSmsCode(phone, countryCode: countryCode);
  }

  /// Signs in with an SMS [code]. Throws [AppException] on failure (wrong
  /// code -> "验证码错误"), the previous session stays untouched.
  Future<UserProfile> signInWithSms(
    String phone,
    String code, {
    int countryCode = 86,
  }) {
    _checkPhone(phone);
    if (code.trim().isEmpty) throw const ApiException(null, '请输入验证码');
    return _attemptLogin(
      () => _host.api.signInWithSms(phone, code, countryCode: countryCode),
    );
  }

  /// Signs in with phone + password (md5 hashed). NetEase often answers
  /// with risk control; the error tells the user to use QR / SMS instead.
  Future<UserProfile> signInWithPassword(
    String phone,
    String password, {
    int countryCode = 86,
  }) {
    _checkPhone(phone);
    if (password.isEmpty) throw const ApiException(null, '请输入密码');
    return _attemptLogin(
      () => _host.api.signInWithPassword(
        phone,
        password,
        countryCode: countryCode,
      ),
    );
  }

  /// Signs in with cookie text copied from a browser
  /// (`MUSIC_U=...; __csrf=...`, a `Cookie:` header or a bare token).
  /// The cookie is installed, validated with the account endpoint and rolled
  /// back when it is not accepted.
  Future<UserProfile> signInWithCookie(String raw) {
    final parsed = NeteaseCookies.parse(raw);
    final token = parsed['MUSIC_U'];
    if (token == null || token.isEmpty) {
      throw const ApiException(null, 'Cookie 中没有 MUSIC_U');
    }
    return _attemptLogin(() async {
      final next = _host.cookies.snapshot()
        // A stale csrf from another account would break weapi writes.
        ..remove('__csrf')
        ..addAll(parsed);
      _host.cookies.restore(next);
      final profile = await _host.api.loginStatus();
      if (profile == null) {
        throw const SessionExpiredException(message: 'Cookie 无效或已过期');
      }
      return profile;
    });
  }

  /// Runs [login] with a cookie snapshot: on any failure the jar is restored
  /// so the previous session (or guest state) is kept.
  Future<UserProfile> _attemptLogin(
    Future<UserProfile> Function() login,
  ) async {
    stopQrLogin();
    final backup = _host.cookies.snapshot();
    try {
      final profile = await login();
      value = SessionState(profile: profile);
      authRevision.value++;
      return profile;
    } catch (_) {
      _host.cookies.restore(backup);
      rethrow;
    }
  }

  static void _checkPhone(String phone) {
    if (!RegExp(r'^\d{5,15}$').hasMatch(phone.trim())) {
      throw const ApiException(400, '手机号格式不正确');
    }
  }

  /// Starts a QR login and completes when the phone confirms (or the user
  /// gives up through [cancelQrLogin]).
  Future<bool> startQrLogin() async {
    stopQrLogin();
    _loginCompleter = Completer<bool>();
    await _requestNewKey();
    _poll();
    return _loginCompleter!.future;
  }

  /// Exposed so the login screen can render its own state.
  final ValueNotifier<QrLoginTicket> qrTicket = ValueNotifier(
    const QrLoginTicket(phase: QrPhase.idle),
  );

  Future<void> _requestNewKey() async {
    qrTicket.value = const QrLoginTicket(phase: QrPhase.loading);
    try {
      final key = await _host.api.loginQrKey();
      qrTicket.value = QrLoginTicket(phase: QrPhase.waiting, key: key);
    } on AppException catch (error) {
      qrTicket.value = QrLoginTicket(
        phase: QrPhase.error,
        message: error.message,
      );
      _complete(false);
    }
  }

  void _poll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 1800),
      (_) => _check(),
    );
    // Fire once immediately so the UI does not wait a full interval.
    _check();
  }

  bool _checking = false;

  Future<void> _check() async {
    final key = qrTicket.value.key;
    if (key == null || _checking) return;
    _checking = true;
    try {
      await _checkOnce(key);
    } finally {
      _checking = false;
    }
  }

  Future<void> _checkOnce(String key) async {
    QrLoginResult result;
    try {
      result = await _host.api.checkQrLogin(key);
    } on AppException catch (error) {
      qrTicket.value = qrTicket.value.copyWith(
        phase: QrPhase.error,
        message: error.message,
      );
      stopQrLogin();
      _complete(false);
      return;
    }
    // The login was cancelled or restarted while the request was in flight.
    if (_pollTimer == null || qrTicket.value.key != key) return;
    switch (result.state) {
      case QrLoginState.riskControl:
        qrTicket.value = qrTicket.value.copyWith(
          phase: QrPhase.error,
          message: '触发网易云安全验证，请稍后重试或改用验证码登录',
        );
        stopQrLogin();
        _complete(false);
      case QrLoginState.waiting:
        qrTicket.value = qrTicket.value.copyWith(phase: QrPhase.waiting);
      case QrLoginState.scanned:
        qrTicket.value = qrTicket.value.copyWith(phase: QrPhase.scanned);
      case QrLoginState.expired:
        qrTicket.value = qrTicket.value.copyWith(phase: QrPhase.expired);
        await _requestNewKey();
      case QrLoginState.confirmed:
        qrTicket.value = qrTicket.value.copyWith(phase: QrPhase.success);
        stopQrLogin();
        await _finishLogin();
      case QrLoginState.unknown:
        // Keep polling, the server sometimes answers with an empty body.
        qrTicket.value = qrTicket.value.copyWith(phase: QrPhase.waiting);
    }
  }

  Future<void> _finishLogin() async {
    // The cookie arrived through `set-cookie` on the poll response, which the
    // HTTP client already stored. The account endpoint lags behind the 803
    // for a moment, so retry a few times before giving up.
    try {
      UserProfile? profile;
      for (var attempt = 0; attempt < 3 && profile == null; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        profile = await _host.api.loginStatus();
      }
      if (profile == null) {
        value = const SessionState(error: '登录未生效，请重新扫码');
        qrTicket.value = qrTicket.value.copyWith(
          phase: QrPhase.error,
          message: '登录未生效，请重新扫码',
        );
        _complete(false);
        return;
      }
      value = SessionState(profile: profile);
      authRevision.value++;
      _complete(true);
    } on AppException catch (error) {
      value = SessionState(error: error.message);
      _complete(false);
    }
  }

  void _complete(bool ok) {
    final completer = _loginCompleter;
    _loginCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete(ok);
  }

  void stopQrLogin() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void cancelQrLogin() {
    stopQrLogin();
    qrTicket.value = const QrLoginTicket(phase: QrPhase.idle);
    _complete(false);
  }

  Future<void> signOut() async {
    try {
      await _host.api.logout();
    } on AppException {
      // The local session is dropped either way.
    }
    _host.cookies.clear();
    value = const SessionState();
    authRevision.value++;
  }

  @override
  void dispose() {
    stopQrLogin();
    _host.onSessionExpired = null;
    super.dispose();
  }
}

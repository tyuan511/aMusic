/// Errors surfaced to the UI.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The API server could not be reached, or the configured address is wrong.
///
/// This is the "transport" failure: retrying another variant of the same
/// request (e.g. a lower audio level) would fail the same way.
class ServerUnreachableException extends AppException {
  const ServerUnreachableException(super.message);
}

/// The API returned a non-200 business code.
///
/// Use [ApiException.fromCode] to get the specialised subtype for the codes
/// NetEase uses for session expiry, risk control and rate limiting.
class ApiException extends AppException {
  const ApiException(this.code, super.message);

  /// Maps a NetEase business [code] to the matching exception type. [message]
  /// is the server text, used only when there is no better fixed wording.
  factory ApiException.fromCode(int? code, [String? message]) {
    final text = message?.trim();
    switch (code) {
      case 301 || -301:
        return SessionExpiredException(code: code);
      case 8821 || -462 || -460:
        return RiskControlException(code);
      case 405:
        return const RateLimitedException();
    }
    return ApiException(
      code,
      text == null || text.isEmpty ? '请求失败 (code: $code)' : text,
    );
  }

  final int? code;

  bool get needLogin => code == 301 || code == -301;

  bool get isRiskControl => code == 8821 || code == -462 || code == -460;

  bool get isRateLimited => code == 405;
}

/// 301: not signed in, or the stored session is no longer valid.
class SessionExpiredException extends ApiException {
  const SessionExpiredException({int? code, String message = '登录已失效，请重新登录'})
    : super(code ?? 301, message);
}

/// 8821 / -462 / -460: NetEase wants a captcha / security check.
class RiskControlException extends ApiException {
  const RiskControlException([int? code])
    : super(code ?? -462, '触发网易云安全验证，请稍后再试或改用扫码登录');
}

/// 405: too many requests in a short time.
class RateLimitedException extends ApiException {
  const RateLimitedException() : super(405, '操作过于频繁，请稍后再试');
}

/// A song cannot be played (greyed out / VIP only / no source found).
class SongUnavailableException extends AppException {
  const SongUnavailableException(super.message);
}

/// Human readable text for any thrown object.
String describeError(Object error) {
  if (error is AppException) return error.message;
  if (error is FormatException) return '数据解析失败: ${error.message}';
  final text = error.toString();
  return text.replaceFirst('Exception: ', '');
}

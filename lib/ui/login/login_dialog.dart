import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/errors.dart';
import '../../models/playlist.dart' show UserProfile;
import '../../services/app.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/kit.dart';

/// Opens the login dialog (QR / SMS / password / cookie). The app is
/// browsable while signed out, so login is an action instead of a gate.
/// Completes with `true` after a successful sign in.
Future<bool> showLoginDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final profile = await showGeneralDialog<UserProfile>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: AppMotion.emphasized,
    pageBuilder: (context, _, _) => const LoginDialog(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  if (profile == null) return false;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('欢迎回来，${profile.nickname}')));
  return true;
}

enum LoginMode {
  qr('扫码'),
  sms('验证码'),
  password('密码'),
  cookie('Cookie');

  const LoginMode(this.label);

  final String label;
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  LoginMode _mode = LoginMode.qr;

  void _done(UserProfile profile) {
    if (mounted) Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            type: MaterialType.transparency,
            child: GlassPanel(
              radius: AppMetrics.radiusLg,
              color: s.card.withValues(alpha: 0.97),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '登录网易云音乐',
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      RoundIconButton(
                        icon: Icons.close_rounded,
                        tooltip: '关闭',
                        size: 36,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '同步歌单、每日推荐与红心',
                    style: context.text.bodySmall?.copyWith(
                      color: s.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ChipBar<LoginMode>(
                    values: LoginMode.values,
                    selected: _mode,
                    labelOf: (mode) => mode.label,
                    dense: true,
                    padding: EdgeInsets.zero,
                    onSelected: (mode) => setState(() => _mode = mode),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSize(
                    duration: AppMotion.standard,
                    curve: AppMotion.enter,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: AppMotion.standard,
                      switchInCurve: AppMotion.enter,
                      switchOutCurve: AppMotion.exit,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_mode),
                        child: switch (_mode) {
                          LoginMode.qr => _QrPanel(onDone: _done),
                          LoginMode.sms => _SmsPanel(onDone: _done),
                          LoginMode.password => _PasswordPanel(onDone: _done),
                          LoginMode.cookie => _CookiePanel(onDone: _done),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _message(Object error) =>
    error is AppException ? error.message : describeError(error);

// ----------------------------------------------------------------------- QR

class _QrPanel extends StatefulWidget {
  const _QrPanel({required this.onDone});

  final ValueChanged<UserProfile> onDone;

  @override
  State<_QrPanel> createState() => _QrPanelState();
}

class _QrPanelState extends State<_QrPanel> {
  /// Panel that started the running QR login. During a quick tab switch an
  /// outgoing panel (still animating out) must not cancel the login a newer
  /// panel just started.
  static _QrPanelState? _owner;

  int _generation = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _owner = this;
    final generation = ++_generation;
    final ok = await app.session.startQrLogin();
    if (!mounted || generation != _generation) return;
    final profile = app.session.value.profile;
    if (ok && profile != null) {
      _finished = true;
      widget.onDone(profile);
    }
  }

  void _refresh() {
    app.session.cancelQrLogin();
    _start();
  }

  @override
  void dispose() {
    // Stop polling when the panel goes away without a login.
    if (_owner == this) {
      _owner = null;
      if (!_finished) app.session.cancelQrLogin();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return ValueListenableBuilder<QrLoginTicket>(
      valueListenable: app.session.qrTicket,
      builder: (context, ticket, _) {
        final stale =
            ticket.phase == QrPhase.expired || ticket.phase == QrPhase.error;
        return Column(
          children: [
            Center(
              child: Container(
                width: 208,
                height: 208,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
                  boxShadow: [BoxShadow(color: s.glow, blurRadius: 24)],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.emphasized,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: Tween(begin: 0.85, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: AppMotion.pop,
                          ),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: ticket.url == null
                          ? const Center(
                              key: ValueKey('loading'),
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          : QrImageView(
                              key: ValueKey(ticket.url),
                              data: ticket.url!,
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.circle,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.circle,
                                color: Colors.black,
                              ),
                            ),
                    ),
                    AnimatedSwitcher(
                      duration: AppMotion.standard,
                      child: switch (ticket.phase) {
                        QrPhase.scanned => const _QrOverlay(
                          key: ValueKey('scanned'),
                          icon: Icons.phone_iphone_rounded,
                          label: '已扫描\n请在手机上确认',
                        ),
                        QrPhase.success => const _QrOverlay(
                          key: ValueKey('success'),
                          icon: Icons.check_circle_rounded,
                          label: '登录成功',
                        ),
                        QrPhase.expired || QrPhase.error => _QrOverlay(
                          key: ValueKey('stale${ticket.phase}'),
                          icon: Icons.refresh_rounded,
                          label: ticket.phase == QrPhase.expired
                              ? '二维码已过期\n点击刷新'
                              : (ticket.message ?? '获取失败\n点击重试'),
                          onTap: _refresh,
                        ),
                        _ => const SizedBox.shrink(key: ValueKey('none')),
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: AppMotion.quick,
              child: Text(
                _status(ticket),
                key: ValueKey(ticket.phase),
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: ticket.phase == QrPhase.error
                      ? context.colors.error
                      : s.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedOpacity(
              duration: AppMotion.quick,
              opacity: stale ? 0 : 1,
              child: TextButton.icon(
                onPressed: stale ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('刷新二维码'),
              ),
            ),
          ],
        );
      },
    );
  }

  String _status(QrLoginTicket ticket) => switch (ticket.phase) {
    QrPhase.idle || QrPhase.loading => '正在获取二维码…',
    QrPhase.waiting => '打开网易云音乐 App，扫一扫登录',
    QrPhase.scanned => '扫描成功，等待手机确认',
    QrPhase.success => '登录成功',
    QrPhase.expired => '二维码已过期',
    QrPhase.error => ticket.message ?? '出错了，请重试',
  };
}

class _QrOverlay extends StatelessWidget {
  const _QrOverlay({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: s.lime, shape: BoxShape.circle),
              child: Icon(icon, size: 26, color: s.onLime),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- shared bits

/// Inline error line that slides in / out.
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);

  final String? error;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.standard,
      curve: AppMotion.enter,
      alignment: Alignment.topLeft,
      child: AnimatedSwitcher(
        duration: AppMotion.quick,
        child: error == null
            ? const SizedBox(width: double.infinity, key: ValueKey('none'))
            : Padding(
                key: ValueKey(error),
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: context.colors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        error!,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.error,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Full width lime submit button with a spinner while [busy].
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: AnimatedSwitcher(
          duration: AppMotion.quick,
          child: busy
              ? SizedBox(
                  key: const ValueKey('busy'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: s.onLime,
                  ),
                )
              : Text(label, key: const ValueKey('label')),
        ),
      ),
    );
  }
}

final RegExp _phonePattern = RegExp(r'^1\d{10}$');

String? _phoneError(String phone) {
  if (phone.isEmpty) return '请输入手机号';
  if (!_phonePattern.hasMatch(phone)) return '请输入 11 位中国大陆手机号';
  return null;
}

InputDecoration _input(
  BuildContext context,
  String hint,
  IconData icon, {
  Widget? suffix,
}) => InputDecoration(
  hintText: hint,
  prefixIcon: Icon(icon, size: 20, color: context.surfaces.textSecondary),
  suffixIcon: suffix,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
    borderSide: BorderSide.none,
  ),
);

// ---------------------------------------------------------------------- SMS

class _SmsPanel extends StatefulWidget {
  const _SmsPanel({required this.onDone});

  final ValueChanged<UserProfile> onDone;

  @override
  State<_SmsPanel> createState() => _SmsPanelState();
}

class _SmsPanelState extends State<_SmsPanel> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  Timer? _timer;
  int _countdown = 0;
  bool _sending = false;
  bool _busy = false;
  String? _error;

  static const int _cooldown = 60;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _phone.text.trim();
    final error = _phoneError(phone);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await app.session.sendSmsCode(phone);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _countdown = _cooldown;
      });
      _codeFocus.requestFocus();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return timer.cancel();
        setState(() => _countdown--);
        if (_countdown <= 0) timer.cancel();
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final code = _code.text.trim();
    final phoneError = _phoneError(phone);
    final error =
        phoneError ??
        (RegExp(r'^\d{4,6}$').hasMatch(code) ? null : '请输入 4-6 位验证码');
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await app.session.signInWithSms(phone, code);
      if (mounted) widget.onDone(profile);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final counting = _countdown > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          textInputAction: TextInputAction.next,
          decoration: _input(context, '手机号', Icons.phone_iphone_rounded),
          onSubmitted: (_) => counting ? _codeFocus.requestFocus() : _send(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                focusNode: _codeFocus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textInputAction: TextInputAction.done,
                decoration: _input(context, '验证码', Icons.sms_rounded),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 112,
              height: 48,
              child: Pressable(
                onTap: counting || _sending ? null : _send,
                child: AnimatedContainer(
                  duration: AppMotion.standard,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: counting ? s.chip : s.lime.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
                  ),
                  child: AnimatedSwitcher(
                    duration: AppMotion.quick,
                    transitionBuilder: (child, animation) => SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: _sending
                        ? const SizedBox(
                            key: ValueKey('sending'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            counting ? '${_countdown}s' : '获取验证码',
                            key: ValueKey(counting ? _countdown : -1),
                            style: context.text.labelLarge?.copyWith(
                              color: counting ? s.textSecondary : s.lime,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        _ErrorText(_error),
        const SizedBox(height: 18),
        _SubmitButton(label: '登录', busy: _busy, onPressed: _submit),
      ],
    );
  }
}

// ----------------------------------------------------------------- password

class _PasswordPanel extends StatefulWidget {
  const _PasswordPanel({required this.onDone});

  final ValueChanged<UserProfile> onDone;

  @override
  State<_PasswordPanel> createState() => _PasswordPanelState();
}

class _PasswordPanelState extends State<_PasswordPanel> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final error =
        _phoneError(phone) ?? (_password.text.isEmpty ? '请输入密码' : null);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await app.session.signInWithPassword(
        phone,
        _password.text,
      );
      if (mounted) widget.onDone(profile);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.username],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            textInputAction: TextInputAction.next,
            decoration: _input(context, '手机号', Icons.phone_iphone_rounded),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: _input(
              context,
              '密码',
              Icons.lock_rounded,
              suffix: IconButton(
                tooltip: _obscure ? '显示密码' : '隐藏密码',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: AnimatedSwitcher(
                  duration: AppMotion.quick,
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    key: ValueKey(_obscure),
                    size: 20,
                    color: s.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          _ErrorText(_error),
          const SizedBox(height: 10),
          Text(
            '密码登录容易触发网易云安全验证，失败时请改用扫码或验证码。',
            style: context.text.bodySmall?.copyWith(
              color: s.textTertiary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _SubmitButton(label: '登录', busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- cookie

class _CookiePanel extends StatefulWidget {
  const _CookiePanel({required this.onDone});

  final ValueChanged<UserProfile> onDone;

  @override
  State<_CookiePanel> createState() => _CookiePanelState();
}

class _CookiePanelState extends State<_CookiePanel> {
  final _cookie = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cookie.dispose();
    super.dispose();
  }

  /// Accepts `MUSIC_U=...` anywhere in the text or a bare token.
  static String? _validate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '请粘贴 Cookie';
    if (text.contains('MUSIC_U=')) return null;
    if (!text.contains('=') && !text.contains(' ') && text.length >= 32) {
      return null;
    }
    return 'Cookie 中需要包含 MUSIC_U';
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _cookie.text = text.trim();
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    final error = _validate(_cookie.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await app.session.signInWithCookie(_cookie.text.trim());
      if (mounted) widget.onDone(profile);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _cookie,
          minLines: 4,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          style: context.text.bodySmall?.copyWith(fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'MUSIC_U=...; __csrf=...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '在浏览器登录 music.163.com 后，从开发者工具复制 Cookie。',
                style: context.text.bodySmall?.copyWith(
                  color: s.textTertiary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PillChip(
              label: '粘贴',
              icon: Icons.content_paste_rounded,
              selected: false,
              dense: true,
              onTap: _paste,
            ),
          ],
        ),
        _ErrorText(_error),
        const SizedBox(height: 16),
        _SubmitButton(label: '登录', busy: _busy, onPressed: _submit),
      ],
    );
  }
}

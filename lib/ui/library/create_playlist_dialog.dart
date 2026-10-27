import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../models/playlist.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';

/// Maximum playlist name length NetEase accepts (in runes).
const int kPlaylistNameMax = 40;

/// Validates a playlist name; `null` when fine.
String? validatePlaylistName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return '请输入歌单名称';
  if (name.runes.length > kPlaylistNameMax) {
    return '名称不能超过 $kPlaylistNameMax 个字';
  }
  return null;
}

/// "新建歌单" dialog. Resolves to the created playlist, or `null` when
/// cancelled.
Future<Playlist?> showCreatePlaylistDialog(BuildContext context) {
  return showDialog<Playlist>(
    context: context,
    builder: (context) => const _CreatePlaylistDialog(),
  );
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final TextEditingController _name = TextEditingController();
  bool _private = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final invalid = validatePlaylistName(_name.text);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final playlist = await app.library.createPlaylist(
        _name.text.trim(),
        private: _private,
      );
      if (mounted) Navigator.pop(context, playlist);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return AlertDialog(
      title: const Text('新建歌单'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: kPlaylistNameMax,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '歌单名称',
                errorText: _error,
                counterStyle: TextStyle(color: s.textTertiary),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: s.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('设为隐私歌单', style: context.text.bodyMedium)),
                Switch(
                  value: _private,
                  onChanged: _busy ? null : (v) => setState(() => _private = v),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: s.onLime,
                  ),
                )
              : const Text('创建'),
        ),
      ],
    );
  }
}

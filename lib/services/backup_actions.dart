import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_lock.dart';
import 'security.dart';
import 'vault.dart';

/// Yedek alma / yükleme işlemleri ve son yedek tarihinin takibi.
class BackupActions {
  BackupActions._();

  static final lastBackup = ValueNotifier<DateTime?>(null);
  static final snoozedUntil = ValueNotifier<DateTime?>(null);

  static Future<void> init() async {
    lastBackup.value = _parse(
      await Security.instance.readSetting('last_backup'),
    );
    snoozedUntil.value = _parse(
      await Security.instance.readSetting('backup_snooze'),
    );
  }

  static DateTime? _parse(String? v) =>
      v == null ? null : DateTime.fromMillisecondsSinceEpoch(int.parse(v));

  /// Yedek hatırlatıcısı gösterilsin mi? (30 günden eski veya hiç yoksa)
  static bool get reminderDue {
    final snooze = snoozedUntil.value;
    if (snooze != null && DateTime.now().isBefore(snooze)) return false;
    final last = lastBackup.value;
    return last == null || DateTime.now().difference(last).inDays >= 30;
  }

  static Future<void> snooze() async {
    final until = DateTime.now().add(const Duration(days: 7));
    snoozedUntil.value = until;
    await Security.instance.writeSetting(
      'backup_snooze',
      '${until.millisecondsSinceEpoch}',
    );
  }

  static void _snack(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// Yedek alır. Başarılıysa true döner.
  static Future<bool> export(BuildContext context) async {
    final pw = await showDialog<String>(
      context: context,
      builder: (_) => const BackupPasswordDialog(confirm: true),
    );
    if (pw == null || !context.mounted) return false;
    try {
      final bytes = await Vault.instance.exportBackup(pw);
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final uri = await AppLock.instance.runWithoutLock(
        () => FilePicker.saveFile(
          dialogTitle: 'Yedeği kaydet',
          fileName: 'sifre_kasam_yedek_$date.skb',
          bytes: bytes,
        ),
      );
      if (uri == null) return false;
      final now = DateTime.now();
      lastBackup.value = now;
      await Security.instance.writeSetting(
        'last_backup',
        '${now.millisecondsSinceEpoch}',
      );
      if (context.mounted) {
        _snack(
          context,
          'Yedek kaydedildi. Dosyayı telefon dışında da saklayın.',
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) _snack(context, 'Yedek alınamadı: $e');
      return false;
    }
  }

  static Future<void> import(BuildContext context) async {
    try {
      final files = await AppLock.instance.runWithoutLock(
        () => FilePicker.pickFiles(dialogTitle: 'Yedek seç'),
      );
      if (files.isEmpty || !context.mounted) return;
      final bytes = await files.first.readAsBytes();
      if (!context.mounted) return;
      final pw = await showDialog<String>(
        context: context,
        builder: (_) => const BackupPasswordDialog(confirm: false),
      );
      if (pw == null) return;
      final n = await Vault.instance.importBackup(bytes, pw);
      if (context.mounted) {
        _snack(
          context,
          n == 0
              ? 'Yedekteki notlar zaten kasada var.'
              : '$n not eklendi veya güncellendi.',
        );
      }
    } on BackupException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (e) {
      if (context.mounted) _snack(context, 'Yedek yüklenemedi: $e');
    }
  }
}

class BackupPasswordDialog extends StatefulWidget {
  final bool confirm;
  const BackupPasswordDialog({super.key, required this.confirm});
  @override
  State<BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<BackupPasswordDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _ok() {
    if (widget.confirm) {
      if (_a.text.length < 6) {
        setState(() => _error = 'En az 6 karakter olmalı');
        return;
      }
      if (_a.text != _b.text) {
        setState(() => _error = 'Şifreler eşleşmiyor');
        return;
      }
    } else if (_a.text.isEmpty) {
      return;
    }
    Navigator.pop(context, _a.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.key_rounded, size: 36),
      title: Text(
        widget.confirm ? 'Yedek şifresi belirleyin' : 'Yedek şifresi',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.confirm)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Bu şifre olmadan yedek açılamaz. Unutmayın.'),
            ),
          TextField(
            controller: _a,
            obscureText: _obscure,
            autofocus: true,
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(
              labelText: 'Şifre',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => widget.confirm ? null : _ok(),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _b,
              obscureText: _obscure,
              enableIMEPersonalizedLearning: false,
              decoration: const InputDecoration(labelText: 'Şifre (tekrar)'),
              onSubmitted: (_) => _ok(),
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Tamam')),
      ],
    );
  }
}

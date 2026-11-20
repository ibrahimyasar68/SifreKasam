import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/app_lock.dart';
import '../services/backup_actions.dart';
import '../services/biometrics.dart';
import '../services/security.dart';
import '../services/theme_controller.dart';
import '../services/vault.dart';
import '../widgets/pin_pad.dart';
import '../widgets/shadow_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  bool _busy = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await Biometrics.available();
    final e = await Security.instance.bioEnabled();
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _bioAvailable = a;
        _bioEnabled = e;
        _version = info.version;
      });
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggleBio(bool v) async {
    if (v) {
      final key = Vault.instance.dataKey;
      if (key == null) return;
      if (!await Security.instance.enableBio(key)) {
        _snack('Biyometrik doğrulama tamamlanmadı.');
        return;
      }
    } else {
      await Security.instance.disableBio();
    }
    if (mounted) setState(() => _bioEnabled = v);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickGrace() async {
    final v = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Uygulamadan çıktıktan sonra bu süre içinde dönerseniz '
                'PIN sorulmaz.',
                textAlign: TextAlign.center,
              ),
            ),
            for (final s in AppLock.graceOptions)
              RadioListTile<int>(
                value: s,
                // ignore: deprecated_member_use
                groupValue: AppLock.instance.graceSeconds,
                // ignore: deprecated_member_use
                onChanged: (v) => Navigator.pop(c, v),
                title: Text(AppLock.graceLabel(s)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (v != null) {
      await AppLock.instance.setGrace(v);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const _Section('Tema'),
            EntranceAnimation(
              child: ShadowCard(
                child: ListenableBuilder(
                  listenable: ThemeController.instance,
                  builder: (context, _) => SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('Sistem'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded),
                          label: Text('Açık'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded),
                          label: Text('Koyu'),
                        ),
                      ],
                      selected: {ThemeController.instance.mode},
                      onSelectionChanged: (v) =>
                          ThemeController.instance.set(v.first),
                    ),
                  ),
                ),
              ),
            ),
            const _Section('Güvenlik'),
            EntranceAnimation(
              index: 1,
              child: ShadowCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    if (_bioAvailable)
                      SwitchListTile(
                        secondary: const _TileIcon(Icons.fingerprint_rounded),
                        title: const Text('Biyometrik giriş'),
                        subtitle: const Text(
                          'Parmak izi veya yüz tanıma ile aç',
                        ),
                        value: _bioEnabled,
                        onChanged: _toggleBio,
                      )
                    else
                      const ListTile(
                        leading: _TileIcon(Icons.fingerprint_rounded),
                        title: Text('Biyometrik giriş'),
                        subtitle: Text(
                          'Cihazda kayıtlı parmak izi / yüz bulunamadı',
                        ),
                        enabled: false,
                      ),
                    ListTile(
                      leading: const _TileIcon(Icons.timer_outlined),
                      title: const Text('Otomatik kilit'),
                      subtitle: Text(
                        AppLock.instance.graceSeconds == 0
                            ? 'Uygulamadan çıkınca hemen'
                            : '${AppLock.graceLabel(AppLock.instance.graceSeconds)} sonra',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickGrace,
                    ),
                    ListTile(
                      leading: const _TileIcon(Icons.pin_rounded),
                      title: const Text('PIN\'i değiştir'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final ok = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePinScreen(),
                          ),
                        );
                        if (ok == true) _snack('PIN değiştirildi.');
                      },
                    ),
                  ],
                ),
              ),
            ),
            const _Section('Yedekleme'),
            EntranceAnimation(
              index: 2,
              child: ShadowCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    ListTile(
                      leading: const _TileIcon(Icons.cloud_upload_rounded),
                      title: const Text('Yedek al'),
                      subtitle: ValueListenableBuilder(
                        valueListenable: BackupActions.lastBackup,
                        builder: (context, last, _) => Text(
                          last == null
                              ? 'Henüz yedek alınmadı'
                              : 'Son yedek: ${DateFormat('d MMMM y', 'tr').format(last)}',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _run(() => BackupActions.export(context)),
                    ),
                    ListTile(
                      leading: const _TileIcon(Icons.cloud_download_rounded),
                      title: const Text('Yedekten yükle'),
                      subtitle: const Text(
                        'Yedek dosyasındaki notları kasaya ekle',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _run(() => BackupActions.import(context)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            EntranceAnimation(
              index: 3,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Notlarınız yalnızca bu telefonda, AES-256 ile '
                        'şifrelenmiş olarak saklanır ve internete gönderilmez. '
                        'Telefon kaybolur, sıfırlanır veya uygulama silinirse '
                        'notlar da gider. Ara sıra yedek alıp dosyayı güvenli '
                        'bir yere kopyalayın. Yedek şifresini unutursanız yedek '
                        'açılamaz.',
                        style: TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Şifre Kasam $_version · İY Labs',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  const _TileIcon(this.icon);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: cs.onPrimaryContainer, size: 22),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Mevcut PIN -> yeni PIN -> yeni PIN tekrar.
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});
  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  int _step = 0;
  String? _newPin;
  SecretKey? _key;
  String? _message;
  bool _isError = false;
  int _errorTick = 0;
  Duration? _lockout;

  @override
  void initState() {
    super.initState();
    Security.instance.lockoutRemaining().then((l) {
      if (mounted && l != null) {
        setState(() {
          _lockout = l;
          _message = 'Çok fazla yanlış deneme. Daha sonra tekrar deneyin.';
          _isError = true;
        });
      }
    });
  }

  Future<void> _onPin(String pin) async {
    switch (_step) {
      case 0:
        final key = await Security.instance.unlockWithPin(pin);
        if (key != null) {
          _key = key;
          await Security.instance.resetFailures();
          setState(() {
            _step = 1;
            _message = null;
            _isError = false;
          });
        } else {
          await Security.instance.registerFailure();
          final l = await Security.instance.lockoutRemaining();
          setState(() {
            _lockout = l;
            _message = l == null
                ? 'Yanlış PIN'
                : 'Çok fazla yanlış deneme. Daha sonra tekrar deneyin.';
            _isError = true;
            _errorTick++;
          });
        }
      case 1:
        setState(() {
          _newPin = pin;
          _step = 2;
          _message = null;
          _isError = false;
        });
      case 2:
        if (pin != _newPin) {
          setState(() {
            _step = 1;
            _message = 'PIN\'ler eşleşmedi, baştan girin';
            _isError = true;
            _errorTick++;
          });
          return;
        }
        await Security.instance.changePin(_key!, pin);
        if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Mevcut PIN', 'Yeni PIN', 'Yeni PIN (tekrar)'];
    return Scaffold(
      appBar: AppBar(title: const Text('PIN\'i değiştir')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PinPad(
            title: titles[_step],
            message: _message,
            isError: _isError,
            errorTick: _errorTick,
            enabled: _lockout == null,
            onCompleted: _onPin,
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_lock.dart';
import '../services/biometrics.dart';
import '../services/security.dart';
import '../theme.dart';
import '../widgets/pin_pad.dart';

/// Kilit katmanı: PIN yoksa kurulum, varsa kilit ekranını gösterir.
class LockGate extends StatelessWidget {
  const LockGate({super.key});

  @override
  Widget build(BuildContext context) {
    final needsSetup = AppLock.instance.status == LockStatus.needsSetup;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      // Kilit ekranı temadan bağımsız olarak her zaman lacivert-altın.
      child: Theme(
        data: AppTheme.build(Brightness.dark),
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.navyLight,
                  AppColors.navy,
                  AppColors.navyDeep,
                ],
                stops: [0, 0.45, 1],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: needsSetup ? const _SetupView() : const _UnlockView(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Colors.black45,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.asset('assets/icon/icon.png', width: 92, height: 92),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Şifre Kasam',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          Text(
            'İY Labs',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: AppColors.goldLight.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Kilit

class _UnlockView extends StatefulWidget {
  const _UnlockView();
  @override
  State<_UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<_UnlockView> with WidgetsBindingObserver {
  bool _bioEnabled = false;
  bool _authInProgress = false;
  DateTime _lastAuthEnd = DateTime(2000);
  String? _message;
  bool _isError = false;
  int _errorTick = 0;
  Duration? _lockout;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final bio =
        await Security.instance.bioEnabled() && await Biometrics.available();
    if (!mounted) return;
    setState(() => _bioEnabled = bio);
    await _refreshLockout();
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _tryBiometric();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Biyometri penceresi kapanınca gelen "resumed" olayını yok say.
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_lastAuthEnd).inMilliseconds > 1500) {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    if (!_bioEnabled ||
        _authInProgress ||
        !mounted ||
        AppLock.instance.status != LockStatus.locked) {
      return;
    }
    _authInProgress = true;
    final key = await Security.instance.unlockWithBio();
    _authInProgress = false;
    _lastAuthEnd = DateTime.now();
    if (key != null) {
      await Security.instance.resetFailures();
      AppLock.instance.unlock(key);
    } else if (!await Security.instance.bioEnabled() && mounted) {
      // Parmak izleri değiştiği için biyometri kapatıldı.
      setState(() {
        _bioEnabled = false;
        _message =
            'Parmak izi ayarları değişmiş. PIN ile girin, sonra '
            'Ayarlar\'dan biyometriyi yeniden açın.';
        _isError = false;
      });
    }
  }

  Future<void> _refreshLockout() async {
    final left = await Security.instance.lockoutRemaining();
    if (!mounted) return;
    setState(() {
      _lockout = left;
      if (left != null) {
        _message = '${left.inSeconds + 1} saniye sonra tekrar deneyin';
        _isError = true;
      }
    });
    _timer?.cancel();
    if (left != null) {
      _timer = Timer(const Duration(seconds: 1), () async {
        await _refreshLockout();
        if (_lockout == null && mounted) setState(() => _message = null);
      });
    }
  }

  Future<void> _onPin(String pin) async {
    final SecretKey? key;
    try {
      key = await Security.instance.unlockWithPin(pin);
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Kasa açılamadı: $e';
          _isError = true;
        });
      }
      return;
    }
    if (key != null) {
      await Security.instance.resetFailures();
      await _offerBioAfterUpgrade(key);
      AppLock.instance.unlock(key);
      return;
    }
    HapticFeedback.heavyImpact();
    await Security.instance.registerFailure();
    if (!mounted) return;
    setState(() {
      _message = 'Yanlış PIN';
      _isError = true;
      _errorTick++;
    });
    await _refreshLockout();
  }

  /// Eski sürümde parmak izi açıksa, yeni güvenli yapıda yeniden açmayı önerir.
  Future<void> _offerBioAfterUpgrade(SecretKey key) async {
    if (!await Security.instance.bioNeedsReEnable()) return;
    if (!await Biometrics.available() || !mounted) {
      await Security.instance.disableBio();
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.fingerprint, size: 40),
        title: const Text('Parmak izini yeniden açın'),
        content: const Text(
          'Kasanız daha güçlü şifrelemeye taşındı. Parmak iziyle açmaya devam '
          'etmek için bir kez doğrulamanız gerekiyor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Şimdi değil'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );
    if (yes != true || !await Security.instance.enableBio(key)) {
      await Security.instance.disableBio();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Header(),
        PinPad(
          title: 'PIN girin',
          message: _message,
          isError: _isError,
          errorTick: _errorTick,
          enabled: _lockout == null,
          onCompleted: _onPin,
          extraKey: _bioEnabled
              ? IconButton(
                  iconSize: 38,
                  color: AppColors.gold,
                  tooltip: 'Parmak izi ile aç',
                  onPressed: _tryBiometric,
                  icon: const Icon(Icons.fingerprint),
                )
              : null,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Kurulum

class _SetupView extends StatefulWidget {
  const _SetupView();
  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  String? _first;
  int _errorTick = 0;
  String? _message = 'Kasanızı açmak için kullanacağınız 6 haneli PIN';
  bool _isError = false;

  Future<void> _onPin(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _message = 'Doğrulamak için aynı PIN\'i tekrar girin';
        _isError = false;
      });
      return;
    }
    if (pin != _first) {
      HapticFeedback.heavyImpact();
      setState(() {
        _first = null;
        _message = 'PIN\'ler eşleşmedi, baştan girin';
        _isError = true;
        _errorTick++;
      });
      return;
    }
    final key = await Security.instance.setupPin(pin);
    if (await Biometrics.available() && mounted) {
      final yes = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.fingerprint, size: 40),
          title: const Text('Biyometrik giriş'),
          content: const Text(
            'Kasayı parmak izi veya yüz tanıma ile de açmak ister misiniz? '
            'PIN her zaman yedek olarak çalışır.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Hayır'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Evet'),
            ),
          ],
        ),
      );
      if (yes == true) await Security.instance.enableBio(key);
    }
    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, size: 40),
          title: const Text('PIN\'inizi unutmayın'),
          content: const Text(
            'Notlarınız bu PIN ile şifrelenir. PIN unutulursa notlar '
            'kurtarılamaz; tek çare yedek dosyasıdır. Düzenli yedek alın.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Anladım'),
            ),
          ],
        ),
      );
    }
    AppLock.instance.unlock(key);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Header(),
        PinPad(
          title: _first == null ? 'PIN belirleyin' : 'PIN\'i onaylayın',
          message: _message,
          isError: _isError,
          errorTick: _errorTick,
          onCompleted: _onPin,
        ),
      ],
    );
  }
}

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

import '../screens/lock_screen.dart';
import 'security.dart';
import 'vault.dart';

enum LockStatus { needsSetup, locked, unlocked }

/// Uygulamanın kilit durumunu yönetir.
///
/// Uygulama arka plana geçer geçmez kilit ekranı en üste konur (içerik
/// hiçbir an açıkta kalmaz). Kullanıcı seçilen bekleme süresi içinde geri
/// dönerse kilit kendiliğinden kalkar; süre geçtiyse PIN / parmak izi ister.
class AppLock extends ChangeNotifier {
  AppLock._();
  static final instance = AppLock._();

  static const graceOptions = [0, 30, 60, 300];

  final navigatorKey = GlobalKey<NavigatorState>();
  LockStatus status = LockStatus.locked;
  Route<void>? _route;
  int _suppress = 0;

  /// Arka planda kilitlenmeden geçebilecek süre (saniye).
  int graceSeconds = 30;
  DateTime? _backgroundAt;

  Future<void> init() async {
    status = await Security.instance.hasPin()
        ? LockStatus.locked
        : LockStatus.needsSetup;
    graceSeconds =
        int.tryParse(await Security.instance.readSetting('grace') ?? '') ?? 30;
  }

  Future<void> setGrace(int seconds) async {
    graceSeconds = seconds;
    notifyListeners();
    await Security.instance.writeSetting('grace', '$seconds');
  }

  static String graceLabel(int s) => switch (s) {
    0 => 'Hemen',
    < 60 => '$s saniye',
    _ => '${s ~/ 60} dakika',
  };

  Route<void> createLockRoute() {
    final r = PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => const LockGate(),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    );
    _route = r;
    return r;
  }

  /// Uygulama arka plana geçtiğinde çağrılır.
  void onBackground() {
    if (_suppress > 0 || status != LockStatus.unlocked) return;
    _backgroundAt = DateTime.now();
    status = LockStatus.locked;
    notifyListeners();
    navigatorKey.currentState?.push(createLockRoute());
  }

  /// Uygulama öne geldiğinde çağrılır: süre dolmadıysa kilidi kaldırır.
  void onForeground() {
    final at = _backgroundAt;
    _backgroundAt = null;
    if (at == null || status != LockStatus.locked) return;
    final key = Vault.instance.dataKey;
    if (key == null || !Vault.instance.loaded) return;
    if (DateTime.now().difference(at).inSeconds < graceSeconds) {
      unlock(key);
    }
  }

  void unlock(SecretKey key) {
    _backgroundAt = null;
    status = LockStatus.unlocked;
    notifyListeners();
    final r = _route;
    _route = null;
    if (r != null && r.isActive) {
      r.navigator?.removeRoute(r);
    }
    Vault.instance.load(key);
  }

  /// Dosya seçici gibi uygulamayı geçici olarak arka plana atan işlemler
  /// sırasında otomatik kilidi devre dışı bırakır.
  Future<T> runWithoutLock<T>(Future<T> Function() action) async {
    _suppress++;
    try {
      return await action();
    } finally {
      Future.delayed(const Duration(milliseconds: 800), () => _suppress--);
    }
  }
}

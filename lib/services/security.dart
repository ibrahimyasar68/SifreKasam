import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// PIN, biyometri ve şifreleme anahtarını yönetir.
///
/// Notları şifreleyen veri anahtarı cihazda açık halde DURMAZ:
/// * PIN'den türetilen bir anahtarla şifrelenmiş olarak saklanır
///   (PIN bilinmeden çözülemez),
/// * biyometri açıksa ikinci bir kopyası, yalnızca parmak izi / yüz
///   doğrulamasıyla açılabilen donanım anahtarıyla saklanır.
class Security {
  Security._();
  static final instance = Security._();

  // resetOnError: false -> bir okuma hatasında veriler asla silinmez.
  final _store = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  // Her okumada güçlü biyometri (parmak izi / yüz) isteyen ayrı depo.
  final _bioStore = const FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      resetOnError: false,
      enforceBiometrics: true,
      requireBiometricsPerOperation: true,
      biometricType: AndroidBiometricType.strongBiometricOnly,
      storageNamespace: 'kasa_bio',
      biometricPromptTitle: 'Şifre Kasam',
      biometricPromptSubtitle: 'Notlarınıza erişmek için doğrulayın',
      biometricPromptNegativeButton: 'PIN kullan',
    ),
  );

  static const _kWrappedKey = 'data_key_pin';
  static const _kBioKey = 'bio_data_key';
  static const _kBio = 'bio_enabled';
  static const _kFails = 'fail_count';
  static const _kLockUntil = 'lock_until';

  // Eski sürüm (1.0) anahtarları: ilk PIN girişinde yeni yapıya taşınır.
  static const _kLegacyPinHash = 'pin_hash';
  static const _kLegacyPinSalt = 'pin_salt';
  static const _kLegacyDataKey = 'data_key';

  static const pinLength = 6;
  static const _legacyPinIterations = 100000;
  static const _wrapIterations = 150000;
  static final _aes = AesGcm.with256bits();

  // ---------------------------------------------------------------- PIN

  Future<bool> hasPin() async =>
      (await _store.read(key: _kWrappedKey)) != null ||
      (await _store.read(key: _kLegacyPinHash)) != null;

  /// İlk kurulum: yeni bir veri anahtarı üretir ve PIN ile kilitler.
  Future<SecretKey> setupPin(String pin) async {
    final key = randomBytes(32);
    await _writeWrapped(pin, key);
    return SecretKey(key);
  }

  /// PIN doğruysa veri anahtarını döndürür, yanlışsa null.
  Future<SecretKey?> unlockWithPin(String pin) async {
    final wrapped = await _store.read(key: _kWrappedKey);
    if (wrapped != null) {
      final key = await _unwrap(pin, wrapped);
      return key == null ? null : SecretKey(key);
    }
    return _migrateLegacy(pin);
  }

  /// PIN'i değiştirir: aynı veri anahtarı yeni PIN ile yeniden kilitlenir.
  Future<void> changePin(SecretKey dataKey, String newPin) async {
    await _writeWrapped(newPin, await dataKey.extractBytes());
  }

  /// Sürüm 1.0'dan geçiş: eski PIN özeti doğrulanır, açıkta duran anahtar
  /// PIN ile kilitlenir, doğrulanır ve ancak ondan sonra eskisi silinir.
  Future<SecretKey?> _migrateLegacy(String pin) async {
    final saltB64 = await _store.read(key: _kLegacyPinSalt);
    final hashB64 = await _store.read(key: _kLegacyPinHash);
    if (saltB64 == null || hashB64 == null) return null;
    final hash = await deriveKey(
      pin,
      base64Decode(saltB64),
      _legacyPinIterations,
    );
    if (!_constantTimeEquals(hash, base64Decode(hashB64))) return null;

    final old = await _store.read(key: _kLegacyDataKey);
    final key = old != null ? base64Decode(old) : randomBytes(32);
    await _writeWrapped(pin, key);
    final check = await _unwrap(pin, (await _store.read(key: _kWrappedKey))!);
    if (check == null || !_constantTimeEquals(check, key)) {
      throw StateError('Anahtar taşıma doğrulanamadı.');
    }
    await _store.delete(key: _kLegacyDataKey);
    await _store.delete(key: _kLegacyPinHash);
    await _store.delete(key: _kLegacyPinSalt);
    // Eski biyometri tercihi yeni yapıda geçersiz: kullanıcı yeniden açar.
    if (await bioEnabled()) await _store.write(key: _kBio, value: 'migrate');
    return SecretKey(key);
  }

  Future<void> _writeWrapped(String pin, List<int> key) async {
    final salt = randomBytes(16);
    final kek = SecretKey(await deriveKey(pin, salt, _wrapIterations));
    final box = await _aes.encrypt(key, secretKey: kek);
    await _store.write(
      key: _kWrappedKey,
      value: jsonEncode({
        'v': 1,
        'it': _wrapIterations,
        's': base64Encode(salt),
        'k': base64Encode(box.concatenation()),
      }),
    );
  }

  Future<List<int>?> _unwrap(String pin, String json) async {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final kek = SecretKey(
      await deriveKey(pin, base64Decode(j['s'] as String), j['it'] as int),
    );
    final box = SecretBox.fromConcatenation(
      base64Decode(j['k'] as String),
      nonceLength: _aes.nonceLength,
      macLength: 16,
      copy: true,
    );
    try {
      return await _aes.decrypt(box, secretKey: kek);
    } on SecretBoxAuthenticationError {
      return null; // yanlış PIN
    }
  }

  // ------------------------------------------------- Yanlış deneme kilidi

  /// Kalan bekleme süresi; bekleme yoksa null.
  Future<Duration?> lockoutRemaining() async {
    final v = await _store.read(key: _kLockUntil);
    if (v == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  /// Yanlış PIN kaydeder. 5 hatadan sonra bekleme süresi her seferinde
  /// ikiye katlanır (30 sn, 1 dk, 2 dk ... en fazla 15 dk).
  Future<void> registerFailure() async {
    final fails = int.parse(await _store.read(key: _kFails) ?? '0') + 1;
    await _store.write(key: _kFails, value: '$fails');
    if (fails >= 5) {
      final secs = min(30 * pow(2, fails - 5).toInt(), 15 * 60);
      final until = DateTime.now().add(Duration(seconds: secs));
      await _store.write(
        key: _kLockUntil,
        value: '${until.millisecondsSinceEpoch}',
      );
    }
  }

  Future<void> resetFailures() async {
    await _store.delete(key: _kFails);
    await _store.delete(key: _kLockUntil);
  }

  // ------------------------------------------------------------ Biyometri

  Future<bool> bioEnabled() async => (await _store.read(key: _kBio)) == '1';

  /// Sürüm 1.0'da biyometri açıktıysa true (yeniden açılması önerilir).
  Future<bool> bioNeedsReEnable() async =>
      (await _store.read(key: _kBio)) == 'migrate';

  /// Veri anahtarının biyometriyle korunan kopyasını yazar. Bu sırada
  /// parmak izi istenir. İptal edilirse false döner.
  Future<bool> enableBio(SecretKey dataKey) async {
    try {
      await _bioStore.write(
        key: _kBioKey,
        value: base64Encode(await dataKey.extractBytes()),
      );
      await _store.write(key: _kBio, value: '1');
      return true;
    } on PlatformException {
      return false;
    }
  }

  Future<void> disableBio() async {
    await _store.write(key: _kBio, value: '0');
    try {
      await _bioStore.delete(key: _kBioKey);
    } on PlatformException {
      // Anahtar zaten geçersizse silinemeyebilir; önemli değil.
    }
  }

  /// Parmak izi / yüz doğrulamasıyla veri anahtarını açar.
  /// İptal veya hata durumunda null döner. Cihaza yeni parmak izi
  /// eklendiyse donanım anahtarı geçersiz olur: biyometri kapatılır.
  Future<SecretKey?> unlockWithBio() async {
    try {
      final v = await _bioStore.read(key: _kBioKey);
      if (v == null) {
        await disableBio();
        return null;
      }
      return SecretKey(base64Decode(v));
    } on PlatformException catch (e) {
      final text = '${e.code} ${e.message}'.toLowerCase();
      if (text.contains('invalid') || text.contains('permanently')) {
        await disableBio();
      }
      return null;
    }
  }

  // ------------------------------------------------------ Ayarlar

  Future<String?> themeMode() => _store.read(key: 'theme_mode');
  Future<void> setThemeMode(String v) =>
      _store.write(key: 'theme_mode', value: v);

  Future<String?> readSetting(String key) => _store.read(key: 'set_$key');
  Future<void> writeSetting(String key, String value) =>
      _store.write(key: 'set_$key', value: value);

  // ------------------------------------------------------------ Yardımcı

  static List<int> randomBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }

  /// PBKDF2-HMAC-SHA256 ile anahtar türetir (arayüz donmasın diye ayrı
  /// isolate'ta çalışır).
  static Future<List<int>> deriveKey(
    String secret,
    List<int> salt,
    int iterations,
  ) {
    return Isolate.run(() async {
      final algo = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );
      final key = await algo.deriveKeyFromPassword(
        password: secret,
        nonce: salt,
      );
      return key.extractBytes();
    });
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

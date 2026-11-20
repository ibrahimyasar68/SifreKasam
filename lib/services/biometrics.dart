import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// Parmak izi / yüz tanıma yardımcıları.
class Biometrics {
  Biometrics._();
  static final _auth = LocalAuthentication();

  static Future<bool> available() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Notlarınıza erişmek için doğrulayın',
        biometricOnly: true,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Şifre Kasam',
            signInHint: 'Parmak izi veya yüz doğrulaması',
            cancelButton: 'PIN kullan',
          ),
        ],
      );
    } catch (_) {
      return false;
    }
  }
}

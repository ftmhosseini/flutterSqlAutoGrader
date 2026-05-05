import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();

  static const _keyEmail = 'bio_email';
  static const _keyPassword = 'bio_password';

  /// Returns true if the device supports biometrics and has enrolled fingers.
  static Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    if (!canCheck) return false;
    final biometrics = await _auth.getAvailableBiometrics();
    return biometrics.isNotEmpty;
  }

  /// Prompts fingerprint/face and returns true on success.
  static Future<bool> authenticate() async {
    return _auth.authenticate(
      localizedReason: 'Authenticate to log in',
      biometricOnly: true,
    );
  }

  /// Save credentials after a successful password login.
  static Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
  }

  /// Returns saved credentials, or null if none stored.
  static Future<({String email, String password})?> getSavedCredentials() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  /// Clear stored credentials (e.g. on logout).
  static Future<void> clearCredentials() async {
    await _storage.deleteAll();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _keyRememberMe = 'remember_me_enabled';
  static const _keySavedEmail = 'saved_email';
  static const _keyAutoLogin = 'auto_login_enabled';

  static Future<void> saveRememberMe({
    required String email,
    required bool remember,
  }) async {
    try {
      await _secureStorage.write(key: _keyRememberMe, value: remember.toString());
      await _secureStorage.write(key: _keySavedEmail, value: email);
      await _secureStorage.write(key: _keyAutoLogin, value: remember.toString());
    } catch (e) {
      debugPrint('[CredentialService] Failed to save remember me: $e');
    }
  }

  static Future<bool> isRememberMeEnabled() async {
    try {
      final value = await _secureStorage.read(key: _keyRememberMe);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getSavedEmail() async {
    try {
      return await _secureStorage.read(key: _keySavedEmail);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> isAutoLoginEnabled() async {
    try {
      final value = await _secureStorage.read(key: _keyAutoLogin);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearAll() async {
    try {
      await _secureStorage.delete(key: _keyRememberMe);
      await _secureStorage.delete(key: _keySavedEmail);
      await _secureStorage.delete(key: _keyAutoLogin);
    } catch (e) {
      debugPrint('[CredentialService] Failed to clear: $e');
    }
  }

  static Future<void> clearAutoLogin() async {
    try {
      await _secureStorage.delete(key: _keyAutoLogin);
      await _secureStorage.delete(key: _keyRememberMe);
    } catch (e) {
      debugPrint('[CredentialService] Failed to clear auto login: $e');
    }
  }
}

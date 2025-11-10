import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  // Login timestamp
  static Future<void> saveLoginTime(String time) async {
    await _storage.write(
      key: 'user_login_timestamp',
      value: time,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  static Future<String?> getLoginTime() async {
    return await _storage.read(
      key: 'user_login_timestamp',
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  static Future<void> deleteLoginTime() async {
    await _storage.delete(
      key: 'user_login_timestamp',
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll(
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }
}

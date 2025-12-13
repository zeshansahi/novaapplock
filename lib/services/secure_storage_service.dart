import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  Future<void> savePin(String pin) async {
    await _storage.write(key: 'app_lock_pin', value: pin);
  }

  Future<String?> getPin() async {
    return await _storage.read(key: 'app_lock_pin');
  }

  Future<void> deletePin() async {
    await _storage.delete(key: 'app_lock_pin');
  }

  Future<bool> hasPin() async {
    final pin = await getPin();
    return pin != null && pin.isNotEmpty;
  }
}


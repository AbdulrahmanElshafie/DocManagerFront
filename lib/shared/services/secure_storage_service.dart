import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  final FlutterSecureStorage _secureStorage;

  // Private constructor
  SecureStorageService._internal() : _secureStorage = const FlutterSecureStorage();

  // Singleton instance
  factory SecureStorageService() {
    return _instance;
  }

  // Store data securely
  Future<void> writeSecureData(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  // Read secure data
  Future<String?> readSecureData(String key) async {
    return await _secureStorage.read(key: key);
  }

  // Delete secure data
  Future<void> deleteSecureData(String key) async {
    await _secureStorage.delete(key: key);
  }

  // Delete all secure data
  Future<void> deleteAllSecureData() async {
    await _secureStorage.deleteAll();
  }

  // Check if key exists
  Future<bool> containsKey(String key) async {
    return await _secureStorage.containsKey(key: key);
  }
} 
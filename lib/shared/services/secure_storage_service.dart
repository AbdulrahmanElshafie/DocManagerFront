import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

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
    if (kIsWeb) {
      // Use window.localStorage for web
      html.window.localStorage[key] = value;
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  // Read secure data
  Future<String?> readSecureData(String key) async {
    if (kIsWeb) {
      // Use window.localStorage for web
      return html.window.localStorage[key];
    } else {
      return await _secureStorage.read(key: key);
    }
  }

  // Delete secure data
  Future<void> deleteSecureData(String key) async {
    if (kIsWeb) {
      // Remove from window.localStorage for web
      html.window.localStorage.remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  // Delete all secure data
  Future<void> deleteAllSecureData() async {
    if (kIsWeb) {
      // Clear all window.localStorage for web
      html.window.localStorage.clear();
    } else {
      await _secureStorage.deleteAll();
    }
  }

  // Check if key exists
  Future<bool> containsKey(String key) async {
    if (kIsWeb) {
      // Check if key exists in window.localStorage
      return html.window.localStorage.containsKey(key);
    } else {
      return await _secureStorage.containsKey(key: key);
    }
  }
} 
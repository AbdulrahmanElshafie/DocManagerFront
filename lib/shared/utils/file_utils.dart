import 'dart:typed_data';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;

// Platform abstraction for File operations
class FileUtils {
  // Create a file path string for cross-platform compatibility
  static String getFileName(dynamic file) {
    if (kIsWeb) {
      return 'web_file';
    } else {
      try {
        return path.basename(file.path);
      } catch (e) {
        return 'unknown_file';
      }
    }
  }

  // Check if file exists (cross-platform)
  static Future<bool> fileExists(dynamic file) async {
    if (kIsWeb) {
      return true; // Assume file exists on web
    } else {
      try {
        return await file.exists();
      } catch (e) {
        return false;
      }
    }
  }

  // Get file path (cross-platform)
  static String? getFilePath(dynamic file) {
    if (kIsWeb) {
      return null; // No path concept on web
    } else {
      try {
        return file.path;
      } catch (e) {
        return null;
      }
    }
  }

  // Read file as bytes (cross-platform)
  static Future<Uint8List> readAsBytes(dynamic file) async {
    if (kIsWeb) {
      throw UnsupportedError('Cannot read local files on web. Use remote files or file picker.');
    } else {
      return await file.readAsBytes();
    }
  }

  // Read file as string (cross-platform)
  static Future<String> readAsString(dynamic file) async {
    if (kIsWeb) {
      throw UnsupportedError('Cannot read local files on web. Use remote files or file picker.');
    } else {
      return await file.readAsString();
    }
  }

  // Write string to file (cross-platform)
  static Future<void> writeAsString(dynamic file, String content) async {
    if (kIsWeb) {
      throw UnsupportedError('Cannot write local files on web.');
    } else {
      await file.writeAsString(content);
    }
  }

  // Get file size (cross-platform)
  static Future<int> getFileSize(dynamic file) async {
    if (kIsWeb) {
      return 0; // Cannot get size on web
    } else {
      try {
        return await file.length();
      } catch (e) {
        return 0;
      }
    }
  }

  // Check if file exists synchronously (cross-platform)
  static bool existsSync(dynamic file) {
    if (kIsWeb) {
      return true; // Assume exists on web
    } else {
      try {
        return file.existsSync();
      } catch (e) {
        return false;
      }
    }
  }

  // Get file size synchronously (cross-platform)
  static int lengthSync(dynamic file) {
    if (kIsWeb) {
      return 0; // Cannot get size on web
    } else {
      try {
        return file.lengthSync();
      } catch (e) {
        return 0;
      }
    }
  }

  // Copy file (cross-platform)
  static Future<void> copyFile(dynamic sourceFile, String destinationPath) async {
    if (kIsWeb) {
      throw UnsupportedError('Cannot copy files on web.');
    } else {
      await sourceFile.copy(destinationPath);
    }
  }
} 
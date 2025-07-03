import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;

class TempFileManager {
  static final Set<String> _createdFiles = <String>{};
  
  static Future<File> createTempFile(String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    _createdFiles.add(tempFile.path);
    return tempFile;
  }
  
  static Future<void> cleanup() async {
    for (String filePath in _createdFiles) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        developer.log('Failed to cleanup temp file: $filePath, error: $e');
      }
    }
    _createdFiles.clear();
  }
  
  static Future<void> cleanupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      _createdFiles.remove(filePath);
    } catch (e) {
      developer.log('Failed to cleanup specific temp file: $filePath, error: $e');
    }
  }
} 
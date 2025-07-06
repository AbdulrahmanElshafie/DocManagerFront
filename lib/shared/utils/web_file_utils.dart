import 'dart:html' as html;
import 'dart:typed_data';

class WebFileUtils {
  static Future<Uint8List> readFileAsBytes(html.File file) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    return reader.result as Uint8List;
  }
  
  static Future<String> readFileAsString(html.File file) async {
    final reader = html.FileReader();
    reader.readAsText(file);
    await reader.onLoad.first;
    return reader.result as String;
  }
  
  static String getFileName(html.File file) {
    return file.name;
  }
  
  static int getFileSize(html.File file) {
    return file.size;
  }
  
  static DateTime getLastModified(html.File file) {
    return file.lastModified != null 
        ? DateTime.fromMillisecondsSinceEpoch(file.lastModified!)
        : DateTime.now();
  }
  
  static String getFileType(html.File file) {
    return file.type;
  }
} 
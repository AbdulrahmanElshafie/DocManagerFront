import 'dart:html' as html;
import 'dart:typed_data';

class WebDownloadHelper {
  static void downloadFile(Uint8List bytes, String fileName) {
    try {
      // Determine MIME type from file extension
      final mimeType = _getMimeTypeFromFileName(fileName);
      
      // Create blob with proper MIME type
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Create invisible anchor element and trigger download
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      
      html.document.body?.children.add(anchor);
      anchor.click();
      
      // Cleanup
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }
  
  static String _getMimeTypeFromFileName(String fileName) {
    final extension = fileName.toLowerCase();
    
    if (extension.endsWith('.pdf')) {
      return 'application/pdf';
    } else if (extension.endsWith('.csv')) {
      return 'text/csv';
    } else if (extension.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    } else if (extension.endsWith('.doc')) {
      return 'application/msword';
    } else if (extension.endsWith('.txt')) {
      return 'text/plain';
    } else if (extension.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    } else if (extension.endsWith('.xls')) {
      return 'application/vnd.ms-excel';
    } else if (extension.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    } else if (extension.endsWith('.ppt')) {
      return 'application/vnd.ms-powerpoint';
    } else if (extension.endsWith('.jpg') || extension.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (extension.endsWith('.png')) {
      return 'image/png';
    } else if (extension.endsWith('.gif')) {
      return 'image/gif';
    } else if (extension.endsWith('.zip')) {
      return 'application/zip';
    } else if (extension.endsWith('.json')) {
      return 'application/json';
    } else if (extension.endsWith('.xml')) {
      return 'application/xml';
    } else {
      return 'application/octet-stream';
    }
  }
} 
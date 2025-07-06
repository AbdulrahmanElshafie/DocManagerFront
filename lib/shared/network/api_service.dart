import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:io' as io show File;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import 'package:doc_manager/shared/services/secure_storage_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'api.dart';
import 'dart:developer' as developer;
import '../utils/file_utils.dart';
import '../utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';

class ApiService {
  final SecureStorageService _secureStorage = SecureStorageService();
  
  // Maximum timeout for sending requests
  static const timeout = Duration(minutes: 2);

  Future<Map<String, String>> _getHeaders({bool isMultipart = false}) async {
    final token = await _secureStorage.readSecureData('authToken');
    return {
      if (!isMultipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String buildUrl(String endpoint, Map<String, dynamic> kwargs) {
    // Start with base URL and endpoint
    String url = API.baseUrl + endpoint;
    
    // Handle ID parameters in the correct order
    if (kwargs.containsKey('id')) {
      url += '${kwargs['id']}/';
    } else if (kwargs.containsKey('doc_id')) {
      url += '${kwargs['doc_id']}/';
      
      // Handle version ID if present
      if (kwargs.containsKey('version_id')) {
        url += '${kwargs['version_id']}/';
      }
    } else if (kwargs.containsKey('token')) {
      url += '${kwargs['token']}/';
    }
    
    return url;
  }

  Future<Map<String, dynamic>> get(String endpoint, Map<String, dynamic> kwargs) async {
    try {
      String url = buildUrl(endpoint, kwargs);
      final headers = await _getHeaders();
      
      AppLogger.debug('GET REQUEST: $url', name: 'ApiService');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      AppLogger.debug('GET RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (e) {
          throw NetworkException('Failed to parse response JSON', 
            statusCode: response.statusCode, originalError: e);
        }
      } else {
        throw NetworkException('Request failed', 
          statusCode: response.statusCode, code: 'HTTP_${response.statusCode}');
      }
    } catch (e) {
      if (e is NetworkException) rethrow;
      AppLogger.error('GET request failed', name: 'ApiService', error: e);
      throw NetworkException('Network request failed', originalError: e);
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data, String id) async {
    try {
      final headers = await _getHeaders();
      final url = id.isEmpty ? '${API.baseUrl}$endpoint' : '${API.baseUrl}$endpoint$id/';
      
      AppLogger.debug('PUT REQUEST: $url', name: 'ApiService');
      AppLogger.debug('PUT DATA: $data', name: 'ApiService');
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: json.encode(data),
      );
      
      AppLogger.debug('PUT RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (e) {
          throw NetworkException('Failed to parse response JSON', 
            statusCode: response.statusCode, originalError: e);
        }
      } else {
        throw NetworkException('Failed to update data', 
          statusCode: response.statusCode, code: 'HTTP_${response.statusCode}');
      }
    } catch (e) {
      if (e is NetworkException) rethrow;
      AppLogger.error('PUT request failed', name: 'ApiService', error: e);
      throw NetworkException('Network request failed', originalError: e);
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint, String id) async {
    try {
      final headers = await _getHeaders();
      final url = '${API.baseUrl}$endpoint$id/';
      
      AppLogger.debug('DELETE REQUEST: $url', name: 'ApiService');
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );
      
      AppLogger.debug('DELETE RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');

      if (response.statusCode == 204 || response.statusCode == 200) {
        return response.body.isEmpty ? {} : json.decode(response.body);
      } else {
        throw NetworkException('Failed to delete data', 
          statusCode: response.statusCode, code: 'HTTP_${response.statusCode}');
      }
    } catch (e) {
      if (e is NetworkException) rethrow;
      AppLogger.error('DELETE request failed', name: 'ApiService', error: e);
      throw NetworkException('Network request failed', originalError: e);
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, Map<String, dynamic> kwargs) async {
    try {
      String url = buildUrl(endpoint, kwargs);
      final headers = await _getHeaders();
      
      AppLogger.debug('POST REQUEST: $url', name: 'ApiService');
      AppLogger.debug('POST DATA: $data', name: 'ApiService');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(data),
      );
      
      AppLogger.debug('POST RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (e) {
          throw NetworkException('Failed to parse response JSON', 
            statusCode: response.statusCode, originalError: e);
        }
      } else {
        throw NetworkException('Failed to create data', 
          statusCode: response.statusCode, code: 'HTTP_${response.statusCode}');
      }
    } catch (e) {
      if (e is NetworkException) rethrow;
      AppLogger.error('POST request failed', name: 'ApiService', error: e);
      throw NetworkException('Network request failed', originalError: e);
    }
  }

  // Helper method to get file information in a platform-agnostic way
  Map<String, dynamic> _getFileInfo(io.File file) {
    if (kIsWeb) {
      // On web, File doesn't have a path property
      return {
        'name': 'web_file',
        'bytes': null,
      };
    } else {
      // On non-web platforms
      try {
        final filePath = FileUtils.getFilePath(file);
        return {
          'name': FileUtils.getFileName(file),
          'path': filePath ?? '',
        };
      } catch (e) {
        return {
          'name': 'unknown_file',
          'path': '',
        };
      }
    }
  }

  // Helper method to check if file exists in a platform-agnostic way
  Future<bool> _fileExists(io.File file) async {
    if (kIsWeb) {
      return true; // Assume file exists on web
    } else {
      try {
        return FileUtils.existsSync(file);
      } catch (e) {
        return false;
      }
    }
  }

  // Helper method to read file bytes in a platform-agnostic way
  Future<List<int>> _readFileBytes(io.File file) async {
    if (kIsWeb) {
      // On web, we need to handle this differently
      throw UnsupportedError('File reading from web File not supported. Use uploadFileFromBytes instead.');
    } else {
      try {
        return await FileUtils.readAsBytes(file);
      } catch (e) {
        throw Exception('Failed to read file bytes: $e');
      }
    }
  }

  Future<Map<String, dynamic>> uploadFile(
      String endpoint, 
      io.File file, 
      Map<String, String> fields) async {
    final url = '${API.baseUrl}$endpoint';
    final headers = await _getHeaders(isMultipart: true);
    
    AppLogger.debug('UPLOAD FILE REQUEST: $url', name: 'ApiService');
    AppLogger.debug('UPLOAD FILE FIELDS: $fields', name: 'ApiService');
    
    // Create multipart request
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(headers);
    
    // Add text fields
    request.fields.addAll(fields);
    
    final fileInfo = _getFileInfo(file);
    final filename = fileInfo['name'] as String;
    final mimeType = _getMimeType(filename);
    
    try {
      // Check if file exists and read bytes
      if (await _fileExists(file)) {
        final bytes = await _readFileBytes(file);
        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: mimeType,
        );
        
        AppLogger.debug('CREATED MULTIPART FILE: ${multipartFile.filename} (${multipartFile.length} bytes), MIME: ${mimeType.toString()}', 
                      name: 'ApiService');
                      
        // Add to request
        request.files.add(multipartFile);
      } else if (!kIsWeb) {
        // Fallback to path-based file upload if reading bytes fails (non-web only)
        AppLogger.warning('Error reading file as bytes, falling back to path-based upload', 
                      name: 'ApiService');
        
        request.files.add(
          await http.MultipartFile.fromPath(
            'file', 
            fileInfo['path'] as String,
            contentType: mimeType,
          )
        );
      } else {
        throw Exception('Cannot upload file on web platform. Use uploadFileFromBytes instead.');
      }
      
      // Send request with timeout
      AppLogger.debug('SENDING MULTIPART REQUEST', name: 'ApiService');
      final streamedResponse = await request.send().timeout(timeout);
      AppLogger.debug('GOT RESPONSE STATUS: ${streamedResponse.statusCode}', name: 'ApiService');
      
      final response = await http.Response.fromStream(streamedResponse);
      
      AppLogger.debug('UPLOAD FILE RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final jsonResponse = json.decode(response.body);
          return jsonResponse;
        } catch (e) {
          AppLogger.error('Error decoding JSON response', name: 'ApiService', error: e);
          // If we can't parse JSON but got a success status, return empty map
          return {};
        }
      } else {
        AppLogger.error('UPLOAD ERROR: Status code ${response.statusCode}', name: 'ApiService');
        throw FileException('Failed to upload file: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      AppLogger.error('UPLOAD EXCEPTION', name: 'ApiService', error: e);
      throw FileException('Failed to upload file: ${filename}', originalError: e);
    }
  }

  // New method specifically for web file uploads using bytes
  Future<Map<String, dynamic>> uploadFileFromBytes(
      String endpoint,
      List<int> bytes,
      String filename,
      Map<String, String> fields) async {
    final url = '${API.baseUrl}$endpoint';
    final headers = await _getHeaders(isMultipart: true);
    
    AppLogger.debug('UPLOAD FILE FROM BYTES REQUEST: $url', name: 'ApiService');
    AppLogger.debug('UPLOAD FILE FIELDS: $fields', name: 'ApiService');
    
    // Create multipart request
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(headers);
    
    // Add text fields
    request.fields.addAll(fields);
    
    // Add file as bytes
    final mimeType = _getMimeType(filename);
    
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: mimeType,
    );
    
    request.files.add(multipartFile);
    
    AppLogger.debug('CREATED MULTIPART FILE FROM BYTES: ${multipartFile.filename} (${multipartFile.length} bytes), MIME: ${mimeType.toString()}', 
                  name: 'ApiService');
    
    // Send request with timeout
    AppLogger.debug('SENDING MULTIPART REQUEST', name: 'ApiService');
    final streamedResponse = await request.send().timeout(timeout);
    AppLogger.debug('GOT RESPONSE STATUS: ${streamedResponse.statusCode}', name: 'ApiService');
    
    final response = await http.Response.fromStream(streamedResponse);
    
    AppLogger.debug('UPLOAD FILE FROM BYTES RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      try {
        final jsonResponse = json.decode(response.body);
        return jsonResponse;
      } catch (e) {
        AppLogger.error('Error decoding JSON response', name: 'ApiService', error: e);
        return {};
      }
    } else {
      AppLogger.error('UPLOAD ERROR: Status code ${response.statusCode}', name: 'ApiService');
      throw FileException('Failed to upload file: ${response.statusCode} - ${response.body}');
    }
  }
  
  Future<Map<String, dynamic>> updateFile(
      String endpoint, 
      String id,
      io.File file, 
      Map<String, String> fields) async {
    final url = '${API.baseUrl}$endpoint$id/';
    final headers = await _getHeaders(isMultipart: true);
    
    AppLogger.debug('UPDATE FILE REQUEST: $url', name: 'ApiService');
    AppLogger.debug('UPDATE FILE FIELDS: $fields', name: 'ApiService');
    
    // Create multipart request
    final request = http.MultipartRequest('PUT', Uri.parse(url));
    request.headers.addAll(headers);
    
    // Add text fields
    request.fields.addAll(fields);
    
    final fileInfo = _getFileInfo(file);
    final filename = fileInfo['name'] as String;
    final mimeType = _getMimeType(filename);
    
    if (!kIsWeb && fileInfo['path'] != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', 
          fileInfo['path'] as String,
          contentType: mimeType,
        )
      );
    } else {
      throw UnsupportedError('File update from web File not supported. Use updateFileFromBytes instead.');
    }
    
    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    AppLogger.debug('UPDATE FILE RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update file: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updateFileFromBytes(
      String endpoint, 
      String id,
      List<int> bytes,
      String filename,
      Map<String, String> fields) async {
    final url = '${API.baseUrl}$endpoint$id/';
    final headers = await _getHeaders(isMultipart: true);
    
    print('UPDATE FILE FROM BYTES REQUEST: $url');
    print('UPDATE FILE FIELDS: $fields');
    
    // Create multipart request
    final request = http.MultipartRequest('PUT', Uri.parse(url));
    request.headers.addAll(headers);
    
    // Add text fields
    request.fields.addAll(fields);
    
    // Add file as bytes
    final mimeType = _getMimeType(filename);
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file', 
        bytes,
        filename: filename,
        contentType: mimeType,
      )
    );
    
    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    print('UPDATE FILE FROM BYTES RESPONSE (${response.statusCode}): ${response.body}');
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update file: ${response.statusCode}');
    }
  }

  MediaType _getMimeType(String filename) {
    final ext = extension(filename).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.pdf':
        return MediaType('application', 'pdf');
      case '.doc':
        return MediaType('application', 'msword');
      case '.docx':
        return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
      case '.csv':
        return MediaType('text', 'csv');
      case '.txt':
        return MediaType('text', 'plain');
      case '.zip':
        return MediaType('application', 'zip');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  Future<List<Map<String, dynamic>>> getList(String endpoint, [Map<String, dynamic>? params]) async {
    Uri uri;
    final headers = await _getHeaders();
    
    if (params != null && params.isNotEmpty) {
      // Convert parameters to query string format
      final queryParams = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      
      uri = Uri.parse('${API.baseUrl}$endpoint?$queryParams');
    } else {
      uri = Uri.parse(API.baseUrl + endpoint);
    }
    
    AppLogger.debug('GETLIST REQUEST: $uri', name: 'ApiService');
    
    final response = await http.get(
      uri,
      headers: headers,
    );
    
    AppLogger.debug('GETLIST RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');

    if (response.statusCode == 200) {
      try {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((item) => item as Map<String, dynamic>).toList();
      } catch (e) {
        AppLogger.error('ERROR parsing JSON list', name: 'ApiService', error: e);
        
        // Try to rescue by checking if the response is actually a different structure
        final dynamic jsonData = json.decode(response.body);
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('results')) {
          List<dynamic> results = jsonData['results'];
          return results.map((item) => item as Map<String, dynamic>).toList();
        }
        
        throw NetworkException('Failed to parse list response', originalError: e);
      }
    } else {
      throw NetworkException('Failed to load list', statusCode: response.statusCode);
    }
  }

  Future<void> updateDocument(String id, String content, String name, String? folderId) async {
    try {
      await put('/manager/document/$id/', {
        'name': name,
        'folder': folderId,
        'content': content,
      }, id);
    } catch (e) {
      throw Exception('Failed to update document: $e');
    }
  }

  Future<void> deleteDocument(String id, String? folderId) async {
    try {
      await delete('/manager/document/', id);
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  Future<void> addDocument(String? folderId, dynamic file, String name) async {
    try {
      final data = <String, dynamic>{
        'name': name,
      };
      if (folderId != null) {
        data['folder'] = folderId;
      }

      await post('/manager/document/', data, {});
    } catch (e) {
      throw Exception('Failed to add document: $e');
    }
  }

  Future<Map<String, dynamic>> updateDocumentContent(String documentId, String content, String contentType) async {
    final headers = await _getHeaders();
    final url = '${API.baseUrl}/manager/document/$documentId/content/';
    
    AppLogger.debug('UPDATE CONTENT REQUEST: $url', name: 'ApiService');
    AppLogger.debug('UPDATE CONTENT DATA: content length: ${content.length}, type: $contentType', name: 'ApiService');
    
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: json.encode({
        'content': content,
        'content_type': contentType,
      }),
    );
    
    AppLogger.debug('UPDATE CONTENT RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update document content: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getDocumentContent(String documentId, String format) async {
    final headers = await _getHeaders();
    final url = '${API.baseUrl}/manager/document/$documentId/content/?format=$format';
    
    AppLogger.debug('GET CONTENT REQUEST: $url', name: 'ApiService');
    
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );
    
    AppLogger.debug('GET CONTENT RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get document content: ${response.statusCode} - ${response.body}');
    }
  }

  Future<List<int>> downloadFile(String url) async {
    AppLogger.debug('DOWNLOAD FILE REQUEST: $url', name: 'ApiService');
    final headers = await _getHeaders();
    
    // Add headers to explicitly request binary data
    final downloadHeaders = {
      ...headers,
      'Accept': 'application/octet-stream, */*',
      'Content-Type': 'application/octet-stream',
    };
    
    final response = await http.get(
      Uri.parse(url), 
      headers: downloadHeaders,
    );
    
    AppLogger.debug('DOWNLOAD FILE RESPONSE (${response.statusCode}): ${response.bodyBytes.length} bytes', name: 'ApiService');

    if (response.statusCode == 200) {
      // Return the raw bytes - this preserves the binary data
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download file: ${response.statusCode} - ${response.body}');
    }
  }

  // Create document with content (used by documents_screen.dart)
  Future<Map<String, dynamic>> createContentDocument({
    required String name,
    String? folderId,
    String? content,
  }) async {
    try {
      final map = {
        'folder': folderId,
        'name': name,
        'content': content ?? '',
        'type': _getFileTypeFromName(name),
      };
      
      AppLogger.debug('Creating document with data: $map', name: 'ApiService');
      final response = await post('/manager/document/', map, {});
      return response;
    } catch (e) {
      AppLogger.error('Error in createContentDocument', name: 'ApiService', error: e);
      rethrow;
    }
  }

  // Helper method to get file type from name
  String _getFileTypeFromName(String name) {
    final extension = name.toLowerCase();
    if (extension.endsWith('.pdf')) {
      return 'pdf';
    } else if (extension.endsWith('.csv')) {
      return 'csv';
    } else if (extension.endsWith('.docx')) {
      return 'docx';
    } else {
      return 'pdf'; // Default
    }
  }
}
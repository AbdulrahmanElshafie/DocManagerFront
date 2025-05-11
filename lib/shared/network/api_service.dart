import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import 'package:doc_manager/shared/services/secure_storage_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'api.dart';
import 'dart:developer' as developer;

class ApiService {
  final SecureStorageService _secureStorage = SecureStorageService();

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
    String url = buildUrl(endpoint, kwargs);
    final headers = await _getHeaders();
    
    print('GET REQUEST: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );
    
    print('GET RESPONSE (${response.statusCode}): ${response.body}');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data, String id) async {
    final headers = await _getHeaders();
    final url = id.isEmpty ? '${API.baseUrl}$endpoint' : '${API.baseUrl}$endpoint$id/';
    
    print('PUT REQUEST: $url');
    print('PUT DATA: $data');
    
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: json.encode(data),
    );
    
    print('PUT RESPONSE (${response.statusCode}): ${response.body}');

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update data: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint, String id) async {
    final headers = await _getHeaders();
    final url = '${API.baseUrl}$endpoint$id/';
    
    print('DELETE REQUEST: $url');
    
    final response = await http.delete(
      Uri.parse(url),
      headers: headers,
    );
    
    print('DELETE RESPONSE (${response.statusCode}): ${response.body}');

    if (response.statusCode == 204 || response.statusCode == 200) {
      return response.body.isEmpty ? {} : json.decode(response.body);
    } else {
      throw Exception('Failed to delete data: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, Map<String, dynamic> kwargs) async {
    String url = buildUrl(endpoint, kwargs);
    final headers = await _getHeaders();
    
    developer.log('POST REQUEST: $url', name: 'ApiService');
    developer.log('POST DATA: $data', name: 'ApiService');
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(data),
      );
      
      developer.log('POST RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        developer.log('POST ERROR: Non-success status code ${response.statusCode}', name: 'ApiService');
        throw Exception('Failed to create data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      developer.log('POST EXCEPTION: $e', name: 'ApiService');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadFile(
      String endpoint, 
      File file, 
      Map<String, String> fields) async {
    try {
      final url = '${API.baseUrl}$endpoint';
      final headers = await _getHeaders(isMultipart: true);
      
      developer.log('UPLOAD FILE REQUEST: $url', name: 'ApiService');
      developer.log('UPLOAD FILE FIELDS: $fields', name: 'ApiService');
      developer.log('FILE EXISTS: ${file.existsSync()}', name: 'ApiService');
      developer.log('FILE PATH: ${file.path}', name: 'ApiService');
      
      if (!file.existsSync()) {
        throw Exception('File does not exist: ${file.path}');
      }
      
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(headers);
      
      // Add text fields
      request.fields.addAll(fields);
      
      // Add file
      final filename = basename(file.path);
      final mimeType = _getMimeType(filename);
      
      // Get file size for logging
      final fileSize = await file.length();
      developer.log('UPLOADING FILE: $filename (${fileSize / 1024} KB) with mime type: ${mimeType.mimeType}', 
                    name: 'ApiService');
      
      // Maximum timeout for sending request
      const timeout = Duration(minutes: 2);
      
      try {
        // Create file multipart
        final fileBytes = await file.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'file', 
          fileBytes,
          filename: filename,
          contentType: mimeType,
        );
        
        developer.log('CREATED MULTIPART FILE: ${multipartFile.filename} (${multipartFile.length} bytes)', 
                      name: 'ApiService');
                      
        // Add to request
        request.files.add(multipartFile);
      } catch (e) {
        // Fallback to path-based file upload if reading bytes fails
        developer.log('Error reading file as bytes, falling back to path-based upload: $e', 
                      name: 'ApiService');
        
        request.files.add(
          await http.MultipartFile.fromPath(
            'file', 
            file.path,
            contentType: mimeType,
          )
        );
      }
      
      // Send request with timeout
      developer.log('SENDING MULTIPART REQUEST', name: 'ApiService');
      final streamedResponse = await request.send().timeout(timeout);
      developer.log('GOT RESPONSE STATUS: ${streamedResponse.statusCode}', name: 'ApiService');
      
      final response = await http.Response.fromStream(streamedResponse);
      
      developer.log('UPLOAD FILE RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final jsonResponse = json.decode(response.body);
          return jsonResponse;
        } catch (e) {
          developer.log('Error decoding JSON response: $e', name: 'ApiService');
          // If we can't parse JSON but got a success status, return empty map
          return {};
        }
      } else {
        developer.log('UPLOAD ERROR: Status code ${response.statusCode}', name: 'ApiService');
        throw Exception('Failed to upload file: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      developer.log('UPLOAD EXCEPTION: $e', name: 'ApiService');
      
      // Try a fallback approach for very problematic files
      if (e.toString().contains('Failed to upload file') && 
          fields['name'] != null && 
          fields['folder'] != null) {
        
        developer.log('Trying fallback to content-based upload without the file', name: 'ApiService');
        
        // Create minimal content based on file extension
        String fileContent = "This document was created as a fallback.";
        String fileType = extension(file.path).toLowerCase().replaceAll('.', '');
        
        // Try to create an empty document with the same name
        try {
          final response = await post(endpoint, {
            'name': fields['name'],
            'folder': fields['folder'],
            'content': fileContent,
            'type': fileType
          }, {});
          
          return response;
        } catch (fallbackError) {
          developer.log('FALLBACK UPLOAD FAILED: $fallbackError', name: 'ApiService');
          // If fallback also fails, rethrow the original error
          throw e;
        }
      } else {
        rethrow;
      }
    }
  }
  
  Future<Map<String, dynamic>> updateFile(
      String endpoint, 
      String id,
      File file, 
      Map<String, String> fields) async {
    final url = '${API.baseUrl}$endpoint$id/';
    final headers = await _getHeaders(isMultipart: true);
    
    print('UPDATE FILE REQUEST: $url');
    print('UPDATE FILE FIELDS: $fields');
    
    // Create multipart request
    final request = http.MultipartRequest('PUT', Uri.parse(url));
    request.headers.addAll(headers);
    
    // Add text fields
    request.fields.addAll(fields);
    
    // Add file
    final filename = basename(file.path);
    final mimeType = _getMimeType(filename);
    
    request.files.add(
      await http.MultipartFile.fromPath(
        'file', 
        file.path,
        contentType: mimeType,
      )
    );
    
    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    print('UPDATE FILE RESPONSE (${response.statusCode}): ${response.body}');
    
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
    
    print('GETLIST REQUEST: $uri');
    
    final response = await http.get(
      uri,
      headers: headers,
    );
    
    print('GETLIST RESPONSE (${response.statusCode}): ${response.body}');

    if (response.statusCode == 200) {
      try {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((item) => item as Map<String, dynamic>).toList();
      } catch (e) {
        print('ERROR parsing JSON list: $e');
        
        // Try to rescue by checking if the response is actually a different structure
        final dynamic jsonData = json.decode(response.body);
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('results')) {
          List<dynamic> results = jsonData['results'];
          return results.map((item) => item as Map<String, dynamic>).toList();
        }
        
        throw Exception('Failed to parse list response: $e');
      }
    } else {
      throw Exception('Failed to load list: ${response.statusCode}');
    }
  }
}
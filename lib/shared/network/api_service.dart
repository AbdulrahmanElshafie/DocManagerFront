import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';

class ApiService {
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Add authorization header when implementing auth
      // 'Authorization': 'Bearer $token',
    };
  }

  String buildUrl(String endpoint, Map<String, dynamic> kwargs) {
    String? id = kwargs['id'],
    token = kwargs['token'],
    docId = kwargs['doc_id'],
    versionId = kwargs['version_id'];

    String url = API.baseUrl + endpoint;
    url += id != null ?  '$id/' : '';
    url += token!= null?  '$token/' : '';
    url += versionId!= null?  '$docId/$versionId/' : '';
    url += docId!= null?  '$docId/' : '';

    return url;
  }

  Future<Map<String, dynamic>> get(String endpoint, Map<String, dynamic> kwargs) async {
    String url = buildUrl(endpoint, kwargs);

    final response = await http.get(
      Uri.parse(url),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data, String id) async {
    
    final response = await http.put(
      Uri.parse('${API.baseUrl}$endpoint$id/'),
      headers: _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update data: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint, String id) async {
    final response = await http.delete(
      Uri.parse('${API.baseUrl}$endpoint$id/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 204 || response.statusCode == 200) {
      return response.body.isEmpty ? {} : json.decode(response.body);
    } else {
      throw Exception('Failed to delete data: ${response.statusCode}');
    }
  }


  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, Map<String, dynamic> kwargs) async {
    String url = buildUrl(endpoint, kwargs);
    
    final response = await http.post(
      Uri.parse(url),
      headers: _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create data: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getList(String endpoint) async {
    final response = await http.get(
      Uri.parse(API.baseUrl + endpoint),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      List<dynamic> jsonList = json.decode(response.body);
      return jsonList.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load list: ${response.statusCode}');
    }
  }
}
import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/version.dart';
import 'package:doc_manager/models/document.dart';
import 'dart:developer' as developer;

class VersionRepository {
  final ApiService _apiService = ApiService();

  Future<Document> createVersion(String documentId, String versionId) async {
    final response = await _apiService.post(API.documentRevisions, {
    }, {
      'doc_id': documentId,
      'version_id': versionId
    });
    return Document.fromJson(response);
  }

  Future<List<Version>> getVersions(String documentId) async {
    try {
      final response = await _apiService.getList(API.documentVersion, {
        "doc_id": documentId
      });
      
      developer.log('Versions response: $response', name: 'VersionRepository');
      
      // Handle empty response or response that indicates no versions
      if (response.isEmpty) {
        return [];
      }
      
      // Handle error responses
      if (response is List && response.isNotEmpty && response[0] is Map<String, dynamic> && 
          response[0].containsKey('error')) {
        developer.log('Error in versions response: ${response[0]['error']}', name: 'VersionRepository');
        return [];
      }
      
      // Parse versions
      try {
        return response.map((item) => Version.fromJson(item)).toList();
      } catch (e) {
        developer.log('Error parsing versions: $e', name: 'VersionRepository');
        return [];
      }
    } catch (e) {
      developer.log('Error getting versions: $e', name: 'VersionRepository');
      // Return empty list instead of crashing
      return [];
    }
  }

  Future<Version> getVersion(String documentId, String versionId) async {
    try {
      final response = await _apiService.get(API.documentRevisions, {
        'doc_id': documentId,
        'version_id': versionId
      });
      
      return Version.fromJson(response);
    } catch (e) {
      developer.log('Error getting version: $e', name: 'VersionRepository');
      rethrow;
    }
  }
}

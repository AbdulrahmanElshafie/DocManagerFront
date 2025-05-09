import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/version.dart';
import 'package:doc_manager/models/document.dart';

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
    final response = await _apiService.get(API.documentRevisions, {
      "doc_id": documentId});
    return (response as List).map((e) => Version.fromJson(e)).toList();
  }

  Future<Version> getVersion(String documentId, String versionId) async {
    final response = await _apiService.get(API.documentRevisions, {
      'doc_id': documentId,
      'version_id': versionId});
    return Version.fromJson(response);
  }

}

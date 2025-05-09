import 'dart:io';
import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/document.dart';

class DocumentRepository {
  final ApiService _apiService = ApiService();

  Future<Document> createDocument(
      String folderId, File file, String name) async {
    final response = await _apiService.post(API.document, {
      'folder': folderId,
      'file': file,
      'name': name
    }, {});
    return Document.fromJson(response);
  }

  Future<List<Document>> getDocuments() async {
    final response = await _apiService.getList(API.document);
    return (response as List).map((e) => Document.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> deleteDocument(String id) async {
    final response = await _apiService.delete(API.document, id);
    return response;
  }

  Future<Map<String, dynamic>> updateDocument(
      String id, String folderId, File file, String name) async {
    final response = await _apiService.put(API.document, {
      'folder': folderId,
      'file': file,
      'name': name
    }, id);
    return response;
  }

  Future<Document> getDocument(String id) async {
    final response = await _apiService.get(API.document, {'id': id});
    return Document.fromJson(response);
  }

}

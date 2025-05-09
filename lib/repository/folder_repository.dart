import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/folder.dart';

class FolderRepository {
  final ApiService _apiService = ApiService();

  Future<Folder> createFolder(
      String parentId, String name) async {
    final response = await _apiService.post(API.folder, {
      'parent': parentId,
      'name': name
    }, {});
    return Folder.fromJson(response);
  }

  Future<List<Folder>> getFolders() async {
    final response = await _apiService.getList(API.folder);
    return (response as List).map((e) => Folder.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> deleteFolder(String id) async {
    final response = await _apiService.delete(API.folder, id);
    return response;
  }

  Future<Map<String, dynamic>> updateFolder(
      String id, String parentId,  String name) async {
    final response = await _apiService.put(API.folder, {
      'parent': parentId,
      'name': name
    }, id);
    return response;
  }

  Future<Folder> getFolder(String id) async {
    final response = await _apiService.get(API.folder, {'id': id});
    return Folder.fromJson(response);
  }

}

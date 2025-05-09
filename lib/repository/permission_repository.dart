import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/permission.dart';

class PermissionRepository {
  final ApiService _apiService = ApiService();

  Future<Permission> createPermission(
      String userId, String? documentId, String? folderId, String level) async {
    final response = await _apiService.post(API.permission, {
      'user': userId,
      'document': documentId,
      'folder': folderId,
      'level': level
    }, {});
    return Permission.fromJson(response);
  }

  Future<List<Permission>> getPermissions() async {
    final response = await _apiService.getList(API.permission);
    return (response as List).map((e) => Permission.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> deletePermission(String id) async {
    final response = await _apiService.delete(API.permission, id);
    return response;
  }

  Future<Map<String, dynamic>> updatePermission(
      String id, String userId, String? documentId,
      String? folderId, String level) async {
    final response = await _apiService.put(API.permission, {
      'user': userId,
      'document': documentId,
      'folder': folderId,
      'level': level
    }, id);
    return response;
  }

  Future<Permission> getPermission(String id) async {
    final response = await _apiService.get(API.permission, {'id': id});
    return Permission.fromJson(response);
  }

}

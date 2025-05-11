import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/folder.dart';
import 'dart:developer' as developer;

class FolderRepository {
  final ApiService _apiService = ApiService();

  Future<Folder> createFolder(
      String? parentId, String name) async {
    final response = await _apiService.post(API.folder, {
      'parent': parentId,
      'name': name
    }, {});
    return Folder.fromJson(response);
  }

  Future<List<Folder>> getFolders() async {
    try {
      final response = await _apiService.getList(API.folder);
      developer.log('Folder response: $response', name: 'FolderRepository');
      
      return response.map((e) => Folder.fromJson(e)).toList();
    } catch (e) {
      developer.log('Error getting folders: $e', name: 'FolderRepository');
      // Return empty list on error instead of crashing
      return [];
    }
  }

  Future<List<Folder>> getFoldersByParent(String? parentId) async {
    try {
      Map<String, dynamic> params = {};
      
      // Explicitly set parentId parameter to ensure proper filtering
      if (parentId != null && parentId.isNotEmpty) {
        params['parent'] = parentId;
      } else {
        // For root folders, explicitly set parent=null to only get top-level folders
        params['parent'] = 'null';
      }
      
      developer.log('Getting folders by parent with params: $params', name: 'FolderRepository');
      final response = await _apiService.getList(API.folder, params);
      developer.log('Folders by parent response: $response', name: 'FolderRepository');
      
      // Double check filter on client side in case API doesn't properly filter
      final folders = response.map((e) => Folder.fromJson(e)).toList();
      
      if (parentId != null && parentId.isNotEmpty) {
        // Only return folders with matching parentId
        return folders.where((folder) => folder.parentId == parentId).toList();
      } else {
        // For root level, only return folders with null or empty parentId
        return folders.where((folder) => folder.parentId == null || folder.parentId!.isEmpty).toList();
      }
    } catch (e) {
      developer.log('Error getting folders by parent: $e', name: 'FolderRepository');
      // Return empty list on error instead of crashing
      return [];
    }
  }

  Future<List<Folder>> searchFolders(String query) async {
    try {
      Map<String, dynamic> params = {'query': query};
      
      final response = await _apiService.getList(API.folder, params);
      return response.map((e) => Folder.fromJson(e)).toList();
    } catch (e) {
      developer.log('Error searching folders: $e', name: 'FolderRepository');
      return [];
    }
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
    try {
      final response = await _apiService.get(API.folder, {'id': id});
      return Folder.fromJson(response);
    } catch (e) {
      developer.log('Error getting folder: $e', name: 'FolderRepository');
      rethrow;
    }
  }
}

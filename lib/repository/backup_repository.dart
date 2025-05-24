import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/backup.dart';
import 'dart:developer' as developer;

class BackupRepository {
  final ApiService _apiService = ApiService();

  Future<Backup> createBackup() async {
    try {
      // According to API docs, backup creation doesn't require document ID
      final response = await _apiService.post(API.backups, {}, {});
      
      developer.log('Create backup response: $response', name: 'BackupRepository');
      return Backup.fromJson(response);
    } catch (e) {
      developer.log('Error creating backup: $e', name: 'BackupRepository');
      rethrow;
    }
  }

  Future<List<Backup>> getBackups({String? documentId}) async {
    try {
      // Filter by document ID if provided
      Map<String, dynamic>? params;
      if (documentId != null) {
        params = {'document': documentId};
      }
      
      final response = await _apiService.getList(API.backups, params);
      developer.log('Get backups response: $response', name: 'BackupRepository');
      
      if (response.isEmpty) {
        return [];
      }
      
      return response.map((e) => Backup.fromJson(e)).toList();
    } catch (e) {
      developer.log('Error getting backups: $e', name: 'BackupRepository');
      return []; // Return empty list on error
    }
  }

  Future<Map<String, dynamic>> deleteBackup(String id) async {
    try {
      final response = await _apiService.delete(API.backups, id);
      developer.log('Delete backup response: $response', name: 'BackupRepository');
      return response;
    } catch (e) {
      developer.log('Error deleting backup: $e', name: 'BackupRepository');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> restoreBackup(String id) async {
    try {
      // To restore a backup, POST to the specific backup ID
      final response = await _apiService.post(
        API.backups, 
        {'action': 'restore'}, // Send restore action in body
        {'id': id}            // Include ID in URL path
      );
      
      developer.log('Restore backup response: $response', name: 'BackupRepository');
      return response;
    } catch (e) {
      developer.log('Error restoring backup: $e', name: 'BackupRepository');
      rethrow;
    }
  }

  Future<Backup> getBackup(String id) async {
    try {
      final response = await _apiService.get(API.backups, {'id': id});
      developer.log('Get backup response: $response', name: 'BackupRepository');
      return Backup.fromJson(response);
    } catch (e) {
      developer.log('Error getting backup: $e', name: 'BackupRepository');
      rethrow;
    }
  }
}

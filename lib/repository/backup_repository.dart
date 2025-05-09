import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/backup.dart';

class BackupRepository {
  final ApiService _apiService = ApiService();

  Future<Backup> createBackup() async {
    final response = await _apiService.post(API.backups, {}, {});
    return Backup.fromJson(response);
  }

  Future<List<Backup>> getBackups() async {
    final response = await _apiService.getList(API.backups);
    return (response as List).map((e) => Backup.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> deleteBackup(String id) async {
    final response = await _apiService.delete(API.backups, id);
    return response;
  }

  Future<Map<String, dynamic>> restoreBackup(String id) async {
    final response = await _apiService.post(API.backups, {}, {'id': id});
    return response;
  }

  Future<Backup> getBackup(String id) async {
    final response = await _apiService.get(API.backups, {'id': id});
    return Backup.fromJson(response);
  }

}

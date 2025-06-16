import 'dart:convert';
import 'package:doc_manager/models/activity_log.dart';
import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class ActivityLogRepository {
  final ApiService _apiService = ApiService();

  /// Get activity logs with optional filters
  Future<List<ActivityLog>> getActivityLogs({
    String? documentId,
    String? activityType,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? ipAddress,
    String? resourceType,
    int? limit,
  }) async {
    try {
      Map<String, String> queryParams = {};
      
      if (documentId != null) queryParams['document'] = documentId;
      if (activityType != null) queryParams['activity_type'] = activityType;
      if (userId != null) queryParams['user'] = userId;
      if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();
      if (ipAddress != null) queryParams['ip_address'] = ipAddress;
      if (resourceType != null) queryParams['resource_type'] = resourceType;
      if (limit != null) queryParams['limit'] = limit.toString();

      final results = await _apiService.getList(API.activityLogs, queryParams);
      return results.map((json) => ActivityLog.fromJson(json)).toList();
    } catch (e) {
      LoggerUtil.error('Error loading activity logs: $e');
      throw Exception('Failed to load activity logs: $e');
    }
  }

  /// Get activity logs for a specific document
  Future<List<ActivityLog>> getDocumentActivityLogs(String documentId, {
    String? activityType,
    int? limit,
  }) async {
    try {
      Map<String, String> queryParams = {'document_id': documentId};
      
      if (activityType != null) queryParams['activity_type'] = activityType;
      if (limit != null) queryParams['limit'] = limit.toString();

      final results = await _apiService.getList(API.documentActivity, queryParams);
      return results.map((json) => ActivityLog.fromJson(json)).toList();
    } catch (e) {
      LoggerUtil.error('Error loading document activity logs: $e');
      throw Exception('Failed to load document activity logs: $e');
    }
  }

  /// Get activity statistics
  Future<Map<String, dynamic>> getActivityStats({
    String? documentId,
    String? resourceType,
  }) async {
    try {
      Map<String, String> queryParams = {};
      
      if (documentId != null) queryParams['document'] = documentId;
      if (resourceType != null) queryParams['resource_type'] = resourceType;

      final response = await _apiService.get(API.activityStats, queryParams);
      return response;
    } catch (e) {
      LoggerUtil.error('Error loading activity stats: $e');
      throw Exception('Failed to load activity stats: $e');
    }
  }

  /// Get folder activity logs
  Future<List<ActivityLog>> getFolderActivityLogs({
    String? folderId,
    String? activityType,
    int? limit,
  }) async {
    try {
      Map<String, String> queryParams = {};
      
      if (folderId != null) queryParams['folder_id'] = folderId;
      if (activityType != null) queryParams['activity_type'] = activityType;
      if (limit != null) queryParams['limit'] = limit.toString();

      final results = await _apiService.getList(API.folderActivity, queryParams);
      return results.map((json) => ActivityLog.fromJson(json)).toList();
    } catch (e) {
      LoggerUtil.error('Error loading folder activity logs: $e');
      throw Exception('Failed to load folder activity logs: $e');
    }
  }

  /// Get a specific activity log by ID
  Future<ActivityLog> getActivityLog(String id) async {
    try {
      final response = await _apiService.get('${API.activityLogs}$id/', {});
      return ActivityLog.fromJson(response);
    } catch (e) {
      LoggerUtil.error('Error loading activity log: $e');
      throw Exception('Failed to load activity log: $e');
    }
  }
} 
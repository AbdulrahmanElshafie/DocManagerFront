import 'package:equatable/equatable.dart';

class ActivityLog extends Equatable {
  final String id;
  final String? documentId;
  final String? folderId;
  final String activityType;
  final String? description;
  final String? username;
  final String? userId;
  final DateTime timestamp;
  final String? ipAddress;
  final String? userAgent;
  final String? resourceType;
  final Map<String, dynamic>? metadata;

  const ActivityLog({
    required this.id,
    this.documentId,
    this.folderId,
    required this.activityType,
    this.description,
    this.username,
    this.userId,
    required this.timestamp,
    this.ipAddress,
    this.userAgent,
    this.resourceType,
    this.metadata,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id']?.toString() ?? '',
      documentId: json['document_id']?.toString(),
      folderId: json['folder_id']?.toString(),
      activityType: json['activity_type'] ?? '',
      description: json['description'],
      username: json['username'],
      userId: json['user_id']?.toString(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      ipAddress: json['ip_address'],
      userAgent: json['user_agent'],
      resourceType: json['resource_type'],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'document_id': documentId,
    'folder_id': folderId,
    'activity_type': activityType,
    'description': description,
    'username': username,
    'user_id': userId,
    'timestamp': timestamp.toIso8601String(),
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'resource_type': resourceType,
    'metadata': metadata,
  };

  ActivityLog copyWith({
    String? id,
    String? documentId,
    String? folderId,
    String? activityType,
    String? description,
    String? username,
    String? userId,
    DateTime? timestamp,
    String? ipAddress,
    String? userAgent,
    String? resourceType,
    Map<String, dynamic>? metadata,
  }) {
    return ActivityLog(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      folderId: folderId ?? this.folderId,
      activityType: activityType ?? this.activityType,
      description: description ?? this.description,
      username: username ?? this.username,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      resourceType: resourceType ?? this.resourceType,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper getter for display name
  String get activityTypeDisplay {
    switch (activityType) {
      case 'view':
        return 'Viewed';
      case 'edit':
        return 'Edited';
      case 'create':
        return 'Created';
      case 'delete':
        return 'Deleted';
      case 'download':
        return 'Downloaded';
      case 'upload':
        return 'Uploaded';
      case 'share':
        return 'Shared';
      case 'permission_change':
        return 'Permission Changed';
      case 'restore':
        return 'Restored';
      case 'rename':
        return 'Renamed';
      case 'move':
        return 'Moved';
      case 'websocket_connect':
        return 'Connected for Live Editing';
      case 'websocket_disconnect':
        return 'Disconnected from Live Editing';
      case 'auto_save':
        return 'Auto Saved';
      case 'manual_save':
        return 'Manually Saved';
      default:
        return activityType.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  List<Object?> get props => [
        id,
        documentId,
        folderId,
        activityType,
        description,
        username,
        userId,
        timestamp,
        ipAddress,
        userAgent,
        resourceType,
        metadata,
      ];
} 
import 'package:equatable/equatable.dart';

abstract class ActivityLogEvent extends Equatable {
  const ActivityLogEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadActivityLogs extends ActivityLogEvent {
  final String? documentId;
  final String? activityType;
  final String? userId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? limit;
  
  const LoadActivityLogs({
    this.documentId,
    this.activityType,
    this.userId,
    this.startDate,
    this.endDate,
    this.limit,
  });
  
  @override
  List<Object?> get props => [documentId, activityType, userId, startDate, endDate, limit];
}

class LoadDocumentActivityLogs extends ActivityLogEvent {
  final String documentId;
  final String? activityType;
  final int? limit;
  
  const LoadDocumentActivityLogs({
    required this.documentId,
    this.activityType,
    this.limit,
  });
  
  @override
  List<Object?> get props => [documentId, activityType, limit];
}

class LoadActivityStats extends ActivityLogEvent {
  final String? documentId;
  final String? resourceType;
  
  const LoadActivityStats({
    this.documentId,
    this.resourceType,
  });
  
  @override
  List<Object?> get props => [documentId, resourceType];
}

class LoadDocumentActivityData extends ActivityLogEvent {
  final String documentId;
  final String? activityType;
  final int? limit;
  final String? resourceType;
  
  const LoadDocumentActivityData({
    required this.documentId,
    this.activityType,
    this.limit,
    this.resourceType,
  });
  
  @override
  List<Object?> get props => [documentId, activityType, limit, resourceType];
}

class RefreshActivityLogs extends ActivityLogEvent {
  final String documentId;
  final int? limit;
  
  const RefreshActivityLogs({
    required this.documentId,
    this.limit,
  });
  
  @override
  List<Object?> get props => [documentId, limit];
} 
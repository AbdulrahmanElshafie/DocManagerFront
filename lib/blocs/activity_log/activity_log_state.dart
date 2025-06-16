import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/activity_log.dart';

abstract class ActivityLogState extends Equatable {
  const ActivityLogState();
  
  @override
  List<Object?> get props => [];
}

class ActivityLogInitial extends ActivityLogState {
  const ActivityLogInitial();
}

class ActivityLogsLoading extends ActivityLogState {
  const ActivityLogsLoading();
}

class ActivityStatsLoading extends ActivityLogState {
  const ActivityStatsLoading();
}

class ActivityLogsLoaded extends ActivityLogState {
  final List<ActivityLog> activityLogs;
  
  const ActivityLogsLoaded(this.activityLogs);
  
  @override
  List<Object?> get props => [activityLogs];
}

class ActivityStatsLoaded extends ActivityLogState {
  final Map<String, dynamic> stats;
  
  const ActivityStatsLoaded(this.stats);
  
  @override
  List<Object?> get props => [stats];
}

class ActivityDataLoaded extends ActivityLogState {
  final List<ActivityLog> activityLogs;
  final Map<String, dynamic> stats;
  
  const ActivityDataLoaded({
    required this.activityLogs,
    required this.stats,
  });
  
  @override
  List<Object?> get props => [activityLogs, stats];
}

class ActivityLogError extends ActivityLogState {
  final String error;
  
  const ActivityLogError(this.error);
  
  @override
  List<Object?> get props => [error];
} 
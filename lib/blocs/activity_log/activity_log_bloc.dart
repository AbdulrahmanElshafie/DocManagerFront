import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/activity_log/activity_log_event.dart';
import 'package:doc_manager/blocs/activity_log/activity_log_state.dart';
import 'package:doc_manager/repository/activity_log_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class ActivityLogBloc extends Bloc<ActivityLogEvent, ActivityLogState> {
  final ActivityLogRepository _activityLogRepository;

  ActivityLogBloc({required ActivityLogRepository activityLogRepository})
      : _activityLogRepository = activityLogRepository,
        super(const ActivityLogInitial()) {
    on<LoadActivityLogs>(_onLoadActivityLogs);
    on<LoadDocumentActivityLogs>(_onLoadDocumentActivityLogs);
    on<LoadActivityStats>(_onLoadActivityStats);
    on<LoadDocumentActivityData>(_onLoadDocumentActivityData);
    on<RefreshActivityLogs>(_onRefreshActivityLogs);
  }

  Future<void> _onLoadActivityLogs(LoadActivityLogs event, Emitter<ActivityLogState> emit) async {
    try {
      emit(const ActivityLogsLoading());
      final activityLogs = await _activityLogRepository.getActivityLogs(
        documentId: event.documentId,
        activityType: event.activityType,
        userId: event.userId,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: event.limit,
      );
      emit(ActivityLogsLoaded(activityLogs));
    } catch (error) {
      LoggerUtil.error('Failed to load activity logs: $error');
      emit(ActivityLogError('Failed to load activity logs: $error'));
    }
  }

  Future<void> _onLoadDocumentActivityLogs(LoadDocumentActivityLogs event, Emitter<ActivityLogState> emit) async {
    try {
      emit(const ActivityLogsLoading());
      final activityLogs = await _activityLogRepository.getDocumentActivityLogs(
        event.documentId,
        activityType: event.activityType,
        limit: event.limit,
      );
      emit(ActivityLogsLoaded(activityLogs));
    } catch (error) {
      LoggerUtil.error('Failed to load document activity logs: $error');
      emit(ActivityLogError('Failed to load document activity logs: $error'));
    }
  }

  Future<void> _onLoadActivityStats(LoadActivityStats event, Emitter<ActivityLogState> emit) async {
    try {
      emit(const ActivityStatsLoading());
      final stats = await _activityLogRepository.getActivityStats(
        documentId: event.documentId,
        resourceType: event.resourceType,
      );
      emit(ActivityStatsLoaded(stats));
    } catch (error) {
      LoggerUtil.error('Failed to load activity stats: $error');
      emit(ActivityLogError('Failed to load activity stats: $error'));
    }
  }

  Future<void> _onLoadDocumentActivityData(LoadDocumentActivityData event, Emitter<ActivityLogState> emit) async {
    try {
      emit(const ActivityLogsLoading());
      
      // Load both activity logs and stats simultaneously
      final futures = await Future.wait([
        _activityLogRepository.getDocumentActivityLogs(
          event.documentId,
          activityType: event.activityType,
          limit: event.limit,
        ),
        _activityLogRepository.getActivityStats(
          documentId: event.documentId,
          resourceType: event.resourceType,
        ),
      ]);
      
      final activityLogs = futures[0] as List<ActivityLog>;
      final stats = futures[1] as Map<String, dynamic>;
      
      emit(ActivityDataLoaded(
        activityLogs: activityLogs,
        stats: stats,
      ));
    } catch (error) {
      LoggerUtil.error('Failed to load document activity data: $error');
      emit(ActivityLogError('Failed to load document activity data: $error'));
    }
  }

  Future<void> _onRefreshActivityLogs(RefreshActivityLogs event, Emitter<ActivityLogState> emit) async {
    try {
      // Don't emit loading state for refresh to avoid flickering
      final activityLogs = await _activityLogRepository.getDocumentActivityLogs(
        event.documentId,
        limit: event.limit,
      );
      emit(ActivityLogsLoaded(activityLogs));
    } catch (error) {
      LoggerUtil.error('Failed to refresh activity logs: $error');
      emit(ActivityLogError('Failed to refresh activity logs: $error'));
    }
  }
} 
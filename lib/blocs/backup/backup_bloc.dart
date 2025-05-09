import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/backup/backup_event.dart';
import 'package:doc_manager/blocs/backup/backup_state.dart';
import 'package:doc_manager/repository/backup_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final BackupRepository _backupRepository;

  BackupBloc({required BackupRepository backupRepository})
      : _backupRepository = backupRepository,
        super(const BackupInitial()) {
    on<LoadBackups>(_onLoadBackups);
    on<LoadBackup>(_onLoadBackup);
    on<CreateBackup>(_onCreateBackup);
    on<RestoreBackup>(_onRestoreBackup);
    on<DeleteBackup>(_onDeleteBackup);
  }

  Future<void> _onLoadBackups(LoadBackups event, Emitter<BackupState> emit) async {
    try {
      emit(const BackupsLoading());
      final backups = await _backupRepository.getBackups();
      emit(BackupsLoaded(backups));
    } catch (error) {
      LoggerUtil.error('Failed to load backups: $error');
      emit(BackupError('Failed to load backups: $error'));
    }
  }

  Future<void> _onLoadBackup(LoadBackup event, Emitter<BackupState> emit) async {
    try {
      emit(const BackupLoading());
      final backup = await _backupRepository.getBackup(event.id);
      emit(BackupLoaded(backup));
    } catch (error) {
      LoggerUtil.error('Failed to load backup: $error');
      emit(BackupError('Failed to load backup: $error'));
    }
  }

  Future<void> _onCreateBackup(CreateBackup event, Emitter<BackupState> emit) async {
    try {
      emit(const BackupsLoading());
      final backup = await _backupRepository.createBackup();
      emit(BackupCreated(backup));
      emit(const BackupOperationSuccess('Backup created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create backup: $error');
      emit(BackupError('Failed to create backup: $error'));
    }
  }

  Future<void> _onRestoreBackup(RestoreBackup event, Emitter<BackupState> emit) async {
    try {
      emit(const BackupsLoading());
      final result = await _backupRepository.restoreBackup(event.id);
      emit(BackupRestored(result));
      emit(const BackupOperationSuccess('Backup restored successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to restore backup: $error');
      emit(BackupError('Failed to restore backup: $error'));
    }
  }

  Future<void> _onDeleteBackup(DeleteBackup event, Emitter<BackupState> emit) async {
    try {
      emit(const BackupsLoading());
      final result = await _backupRepository.deleteBackup(event.id);
      emit(BackupDeleted(result));
      emit(const BackupOperationSuccess('Backup deleted successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to delete backup: $error');
      emit(BackupError('Failed to delete backup: $error'));
    }
  }
} 
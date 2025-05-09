import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/permission/permission_event.dart';
import 'package:doc_manager/blocs/permission/permission_state.dart';
import 'package:doc_manager/repository/permission_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class PermissionBloc extends Bloc<PermissionEvent, PermissionState> {
  final PermissionRepository _permissionRepository;

  PermissionBloc({required PermissionRepository permissionRepository})
      : _permissionRepository = permissionRepository,
        super(const PermissionInitial()) {
    on<LoadPermissions>(_onLoadPermissions);
    on<LoadPermission>(_onLoadPermission);
    on<CreatePermission>(_onCreatePermission);
    on<UpdatePermission>(_onUpdatePermission);
    on<DeletePermission>(_onDeletePermission);
  }

  Future<void> _onLoadPermissions(LoadPermissions event, Emitter<PermissionState> emit) async {
    try {
      emit(const PermissionsLoading());
      final permissions = await _permissionRepository.getPermissions();
      emit(PermissionsLoaded(permissions));
    } catch (error) {
      LoggerUtil.error('Failed to load permissions: $error');
      emit(PermissionError('Failed to load permissions: $error'));
    }
  }

  Future<void> _onLoadPermission(LoadPermission event, Emitter<PermissionState> emit) async {
    try {
      emit(const PermissionLoading());
      final permission = await _permissionRepository.getPermission(event.id);
      emit(PermissionLoaded(permission));
    } catch (error) {
      LoggerUtil.error('Failed to load permission: $error');
      emit(PermissionError('Failed to load permission: $error'));
    }
  }

  Future<void> _onCreatePermission(CreatePermission event, Emitter<PermissionState> emit) async {
    try {
      emit(const PermissionsLoading());
      final permission = await _permissionRepository.createPermission(
        event.userId,
        event.documentId,
        event.folderId,
        event.level
      );
      emit(PermissionCreated(permission));
      emit(const PermissionOperationSuccess('Permission created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create permission: $error');
      emit(PermissionError('Failed to create permission: $error'));
    }
  }

  Future<void> _onUpdatePermission(UpdatePermission event, Emitter<PermissionState> emit) async {
    try {
      emit(const PermissionsLoading());
      final result = await _permissionRepository.updatePermission(
        event.id,
        event.userId,
        event.documentId,
        event.folderId,
        event.level
      );
      emit(PermissionUpdated(result));
      emit(const PermissionOperationSuccess('Permission updated successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to update permission: $error');
      emit(PermissionError('Failed to update permission: $error'));
    }
  }

  Future<void> _onDeletePermission(DeletePermission event, Emitter<PermissionState> emit) async {
    try {
      emit(const PermissionsLoading());
      final result = await _permissionRepository.deletePermission(event.id);
      emit(PermissionDeleted(result));
      emit(const PermissionOperationSuccess('Permission deleted successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to delete permission: $error');
      emit(PermissionError('Failed to delete permission: $error'));
    }
  }
} 
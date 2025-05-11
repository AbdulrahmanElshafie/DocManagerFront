import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/permission.dart';

abstract class PermissionEvent extends Equatable {
  const PermissionEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadPermissions extends PermissionEvent {
  const LoadPermissions();
}

class GetPermissions extends PermissionEvent {
  final String resourceId;
  
  const GetPermissions({required this.resourceId});
  
  @override
  List<Object?> get props => [resourceId];
}

class LoadPermission extends PermissionEvent {
  final String id;
  
  const LoadPermission(this.id);
  
  @override
  List<Object?> get props => [id];
}

class CreatePermission extends PermissionEvent {
  final String userId;
  final String? documentId;
  final String? folderId;
  final String level;
  final String? resourceId;
  final String? permissionType;
  
  const CreatePermission({
    required this.userId,
    this.documentId,
    this.folderId,
    required this.level,
    this.resourceId,
    this.permissionType,
  });
  
  @override
  List<Object?> get props => [userId, documentId, folderId, level, resourceId, permissionType];
}

class UpdatePermission extends PermissionEvent {
  final String id;
  final String userId;
  final String? documentId;
  final String? folderId;
  final String level;
  final String? permissionType;
  
  const UpdatePermission({
    required this.id,
    required this.userId,
    this.documentId,
    this.folderId,
    required this.level,
    this.permissionType,
  });
  
  @override
  List<Object?> get props => [id, userId, documentId, folderId, level, permissionType];
}

class DeletePermission extends PermissionEvent {
  final String id;
  
  const DeletePermission({required this.id});
  
  @override
  List<Object?> get props => [id];
} 
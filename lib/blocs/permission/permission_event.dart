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
  
  const CreatePermission({
    required this.userId,
    this.documentId,
    this.folderId,
    required this.level,
  });
  
  @override
  List<Object?> get props => [userId, documentId, folderId, level];
}

class UpdatePermission extends PermissionEvent {
  final String id;
  final String userId;
  final String? documentId;
  final String? folderId;
  final String level;
  
  const UpdatePermission({
    required this.id,
    required this.userId,
    this.documentId,
    this.folderId,
    required this.level,
  });
  
  @override
  List<Object?> get props => [id, userId, documentId, folderId, level];
}

class DeletePermission extends PermissionEvent {
  final String id;
  
  const DeletePermission(this.id);
  
  @override
  List<Object?> get props => [id];
} 
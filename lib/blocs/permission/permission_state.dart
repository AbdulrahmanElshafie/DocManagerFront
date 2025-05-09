import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/permission.dart';

abstract class PermissionState extends Equatable {
  const PermissionState();
  
  @override
  List<Object?> get props => [];
}

class PermissionInitial extends PermissionState {
  const PermissionInitial();
}

class PermissionsLoading extends PermissionState {
  const PermissionsLoading();
}

class PermissionLoading extends PermissionState {
  const PermissionLoading();
}

class PermissionsLoaded extends PermissionState {
  final List<Permission> permissions;
  
  const PermissionsLoaded(this.permissions);
  
  @override
  List<Object?> get props => [permissions];
}

class PermissionLoaded extends PermissionState {
  final Permission permission;
  
  const PermissionLoaded(this.permission);
  
  @override
  List<Object?> get props => [permission];
}

class PermissionCreated extends PermissionState {
  final Permission permission;
  
  const PermissionCreated(this.permission);
  
  @override
  List<Object?> get props => [permission];
}

class PermissionUpdated extends PermissionState {
  final Map<String, dynamic> result;
  
  const PermissionUpdated(this.result);
  
  @override
  List<Object?> get props => [result];
}

class PermissionDeleted extends PermissionState {
  final Map<String, dynamic> result;
  
  const PermissionDeleted(this.result);
  
  @override
  List<Object?> get props => [result];
}

class PermissionOperationSuccess extends PermissionState {
  final String message;
  
  const PermissionOperationSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class PermissionError extends PermissionState {
  final String error;
  
  const PermissionError(this.error);
  
  @override
  List<Object?> get props => [error];
} 
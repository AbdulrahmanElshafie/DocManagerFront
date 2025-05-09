import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/version.dart';
import 'package:doc_manager/models/document.dart';

abstract class VersionState extends Equatable {
  const VersionState();
  
  @override
  List<Object?> get props => [];
}

class VersionInitial extends VersionState {
  const VersionInitial();
}

class VersionsLoading extends VersionState {
  const VersionsLoading();
}

class VersionLoading extends VersionState {
  const VersionLoading();
}

class VersionsLoaded extends VersionState {
  final List<Version> versions;
  
  const VersionsLoaded(this.versions);
  
  @override
  List<Object?> get props => [versions];
}

class VersionLoaded extends VersionState {
  final Version version;
  
  const VersionLoaded(this.version);
  
  @override
  List<Object?> get props => [version];
}

class VersionCreated extends VersionState {
  final Document document;
  
  const VersionCreated(this.document);
  
  @override
  List<Object?> get props => [document];
}

class VersionOperationSuccess extends VersionState {
  final String message;
  
  const VersionOperationSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class VersionError extends VersionState {
  final String error;
  
  const VersionError(this.error);
  
  @override
  List<Object?> get props => [error];
} 
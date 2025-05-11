import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/backup.dart';

abstract class BackupState extends Equatable {
  const BackupState();
  
  @override
  List<Object?> get props => [];
}

class BackupInitial extends BackupState {
  const BackupInitial();
}

class BackupsLoading extends BackupState {
  const BackupsLoading();
}

class BackupLoading extends BackupState {
  const BackupLoading();
}

class BackupsLoaded extends BackupState {
  final List<Backup> backups;
  
  const BackupsLoaded(this.backups);
  
  @override
  List<Object?> get props => [backups];
}

class BackupLoaded extends BackupState {
  final Backup backup;
  
  const BackupLoaded(this.backup);
  
  @override
  List<Object?> get props => [backup];
}

class BackupCreated extends BackupState {
  final Backup backup;
  
  const BackupCreated(this.backup);
  
  @override
  List<Object?> get props => [backup];
}

class BackupRestored extends BackupState {
  final Map<String, dynamic> result;
  
  const BackupRestored(this.result);
  
  @override
  List<Object?> get props => [result];
}

class BackupDeleted extends BackupState {
  final Map<String, dynamic> result;
  
  const BackupDeleted(this.result);
  
  @override
  List<Object?> get props => [result];
}

class BackupSuccess extends BackupState {
  final String message;
  
  const BackupSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class BackupError extends BackupState {
  final String error;
  
  const BackupError(this.error);
  
  @override
  List<Object?> get props => [error];
} 
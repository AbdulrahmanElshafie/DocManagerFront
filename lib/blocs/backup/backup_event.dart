import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/backup.dart';

abstract class BackupEvent extends Equatable {
  const BackupEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadBackups extends BackupEvent {
  const LoadBackups();
}

class LoadBackup extends BackupEvent {
  final String id;
  
  const LoadBackup(this.id);
  
  @override
  List<Object?> get props => [id];
}

class CreateBackup extends BackupEvent {
  const CreateBackup();
}

class RestoreBackup extends BackupEvent {
  final String id;
  
  const RestoreBackup(this.id);
  
  @override
  List<Object?> get props => [id];
}

class DeleteBackup extends BackupEvent {
  final String id;
  
  const DeleteBackup(this.id);
  
  @override
  List<Object?> get props => [id];
} 
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

class GetBackupsByDocument extends BackupEvent {
  final String documentId;
  
  const GetBackupsByDocument({required this.documentId});
  
  @override
  List<Object?> get props => [documentId];
}

class GetAllBackups extends BackupEvent {
  const GetAllBackups();
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
  
  const RestoreBackup({required this.id});
  
  @override
  List<Object?> get props => [id];
}

class DeleteBackup extends BackupEvent {
  final String id;
  
  const DeleteBackup({required this.id});
  
  @override
  List<Object?> get props => [id];
} 
import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/folder.dart';

abstract class FolderEvent extends Equatable {
  const FolderEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadFolders extends FolderEvent {
  const LoadFolders();
}

class LoadFolder extends FolderEvent {
  final String id;
  
  const LoadFolder(this.id);
  
  @override
  List<Object?> get props => [id];
}

class CreateFolder extends FolderEvent {
  final String parentId;
  final String name;
  
  const CreateFolder({
    required this.parentId,
    required this.name
  });
  
  @override
  List<Object?> get props => [parentId, name];
}

class UpdateFolder extends FolderEvent {
  final String id;
  final String parentId;
  final String name;
  
  const UpdateFolder({
    required this.id,
    required this.parentId,
    required this.name
  });
  
  @override
  List<Object?> get props => [id, parentId, name];
}

class DeleteFolder extends FolderEvent {
  final String id;
  
  const DeleteFolder(this.id);
  
  @override
  List<Object?> get props => [id];
} 
import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/folder.dart';

abstract class FolderState extends Equatable {
  const FolderState();
  
  @override
  List<Object?> get props => [];
}

class FolderInitial extends FolderState {
  const FolderInitial();
}

class FoldersLoading extends FolderState {
  const FoldersLoading();
}

class FolderLoading extends FolderState {
  const FolderLoading();
}

class FoldersLoaded extends FolderState {
  final List<Folder> folders;
  
  const FoldersLoaded(this.folders);
  
  @override
  List<Object?> get props => [folders];
}

class FolderLoaded extends FolderState {
  final Folder folder;
  
  List<Folder> get folders => [folder];
  
  const FolderLoaded(this.folder);
  
  @override
  List<Object?> get props => [folder];
}

class FolderCreated extends FolderState {
  final Folder folder;
  
  const FolderCreated(this.folder);
  
  @override
  List<Object?> get props => [folder];
}

class FolderUpdated extends FolderState {
  final Map<String, dynamic> result;
  
  const FolderUpdated(this.result);
  
  @override
  List<Object?> get props => [result];
}

class FolderDeleted extends FolderState {
  final Map<String, dynamic> result;
  
  const FolderDeleted(this.result);
  
  @override
  List<Object?> get props => [result];
}

class FolderOperationSuccess extends FolderState {
  final String message;
  
  const FolderOperationSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class FolderError extends FolderState {
  final String error;
  
  const FolderError(this.error);
  
  @override
  List<Object?> get props => [error];
} 
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/document.dart';

abstract class DocumentEvent extends Equatable {
  const DocumentEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadDocuments extends DocumentEvent {
  const LoadDocuments();
}

class LoadDocument extends DocumentEvent {
  final String id;
  
  const LoadDocument(this.id);
  
  @override
  List<Object?> get props => [id];
}

class AddDocument extends DocumentEvent {
  final String folderId;
  final File file;
  final String name;
  
  const AddDocument({
    required this.folderId, 
    required this.file, 
    required this.name
  });
  
  @override
  List<Object?> get props => [folderId, file, name];
}

class UpdateDocument extends DocumentEvent {
  final String id;
  final String folderId;
  final File file;
  final String name;
  
  const UpdateDocument({
    required this.id,
    required this.folderId, 
    required this.file, 
    required this.name
  });
  
  @override
  List<Object?> get props => [id, folderId, file, name];
}

class DeleteDocument extends DocumentEvent {
  final String id;
  
  const DeleteDocument(this.id);
  
  @override
  List<Object?> get props => [id];
} 
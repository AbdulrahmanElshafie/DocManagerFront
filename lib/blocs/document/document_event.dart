import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:io' as io show File;
import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/document.dart';

abstract class DocumentEvent extends Equatable {
  const DocumentEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadDocuments extends DocumentEvent {
  final String? folderId;
  final String? query;
  
  const LoadDocuments({this.folderId, this.query});
  
  @override
  List<Object?> get props => [folderId, query];
}

class LoadDocument extends DocumentEvent {
  final String id;
  
  const LoadDocument(this.id);
  
  @override
  List<Object?> get props => [id];
}

class CreateDocument extends DocumentEvent {
  final String name;
  final String? folderId;
  final String? content;
  
  const CreateDocument({
    required this.name,
    this.folderId,
    this.content,
  });
  
  @override
  List<Object?> get props => [name, folderId, content];
}

class AddDocument extends DocumentEvent {
  final String? folderId;
  final io.File file;
  final String name;
  
  const AddDocument({
    this.folderId, 
    required this.file, 
    required this.name
  });
  
  @override
  List<Object?> get props => [folderId, file, name];
}

class AddDocumentFromBytes extends DocumentEvent {
  final String? folderId;
  final List<int> fileBytes;
  final String fileName;
  final String name;
  
  const AddDocumentFromBytes({
    this.folderId, 
    required this.fileBytes,
    required this.fileName,
    required this.name
  });
  
  @override
  List<Object?> get props => [folderId, fileBytes, fileName, name];
}

class UpdateDocument extends DocumentEvent {
  final String id;
  final String? folderId;
  final io.File? file;
  final String? name;
  final String? content;
  
  const UpdateDocument({
    required this.id,
    this.folderId, 
    this.file, 
    this.name,
    this.content,
  });
  
  @override
  List<Object?> get props => [id, folderId, file, name, content];
}

class DeleteDocument extends DocumentEvent {
  final String id;
  final String? folderId;
  
  const DeleteDocument(this.id, {this.folderId});
  
  @override
  List<Object?> get props => [id, folderId];
}

class RestoreVersion extends DocumentEvent {
  final String documentId;
  final String versionId;
  
  const RestoreVersion({
    required this.documentId,
    required this.versionId,
  });
  
  @override
  List<Object?> get props => [documentId, versionId];
} 
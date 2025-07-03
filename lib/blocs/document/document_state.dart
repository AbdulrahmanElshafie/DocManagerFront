import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/document.dart';

abstract class DocumentState extends Equatable {
  const DocumentState();
  
  @override
  List<Object?> get props => [];
}

class DocumentInitial extends DocumentState {
  const DocumentInitial();
}

class DocumentsLoading extends DocumentState {
  const DocumentsLoading();
}

class DocumentLoading extends DocumentState {
  const DocumentLoading();
}

class DocumentsLoaded extends DocumentState {
  final List<Document> documents;
  final String? successMessage;
  
  const DocumentsLoaded(this.documents, {this.successMessage});
  
  @override
  List<Object?> get props => [documents, successMessage];
}

class DocumentLoaded extends DocumentState {
  final Document document;
  
  const DocumentLoaded(this.document);
  
  @override
  List<Object?> get props => [document];
}

class DocumentCreated extends DocumentState {
  final Document document;
  
  const DocumentCreated(this.document);
  
  @override
  List<Object?> get props => [document];
}

class DocumentUpdated extends DocumentState {
  final Map<String, dynamic> result;
  
  const DocumentUpdated(this.result);
  
  @override
  List<Object?> get props => [result];
}

class DocumentDeleted extends DocumentState {
  final Map<String, dynamic> result;
  
  const DocumentDeleted(this.result);
  
  @override
  List<Object?> get props => [result];
}

class DocumentVersionRestored extends DocumentState {
  final Map<String, dynamic> result;
  
  const DocumentVersionRestored(this.result);
  
  @override
  List<Object?> get props => [result];
}

class DocumentOperationSuccess extends DocumentState {
  final String message;
  
  const DocumentOperationSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class DocumentError extends DocumentState {
  final String error;
  
  const DocumentError(this.error);
  
  @override
  List<Object?> get props => [error];
}

// Combined state classes to prevent multiple emissions
class DocumentCreatedWithList extends DocumentState {
  final Document document;
  final List<Document> documents;
  
  const DocumentCreatedWithList({
    required this.document,
    required this.documents,
  });
  
  @override
  List<Object> get props => [document, documents];
}

class DocumentUpdatedWithList extends DocumentState {
  final Map<String, dynamic> updateResult;
  final Document document;
  final List<Document>? documents;
  
  const DocumentUpdatedWithList({
    required this.updateResult,
    required this.document,
    this.documents,
  });
  
  @override
  List<Object?> get props => [updateResult, document, documents];
}

class DocumentDeletedWithList extends DocumentState {
  final Map<String, dynamic> deleteResult;
  final List<Document>? documents;
  
  const DocumentDeletedWithList({
    required this.deleteResult,
    this.documents,
  });
  
  @override
  List<Object?> get props => [deleteResult, documents];
} 
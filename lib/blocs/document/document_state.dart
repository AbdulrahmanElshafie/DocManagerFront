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
  
  const DocumentsLoaded(this.documents);
  
  @override
  List<Object?> get props => [documents];
}

class DocumentLoaded extends DocumentState {
  final Document document;
  
  const DocumentLoaded(this.document);
  
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
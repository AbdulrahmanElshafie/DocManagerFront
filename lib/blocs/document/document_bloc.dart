import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/blocs/document/document_state.dart';
import 'package:doc_manager/repository/document_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';
import 'dart:developer' as developer;

class DocumentBloc extends Bloc<DocumentEvent, DocumentState> {
  final DocumentRepository _documentRepository;

  DocumentBloc({required DocumentRepository documentRepository}) 
    : _documentRepository = documentRepository,
      super(const DocumentInitial()) {
    on<LoadDocuments>(_onLoadDocuments);
    on<LoadDocument>(_onLoadDocument);
    on<AddDocument>(_onAddDocument);
    on<CreateDocument>(_onCreateDocument);
    on<UpdateDocument>(_onUpdateDocument);
    on<DeleteDocument>(_onDeleteDocument);
    on<RestoreVersion>(_onRestoreVersion);
  }

  Future<void> _onLoadDocuments(LoadDocuments event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      final documents = await _documentRepository.getDocuments(
        folderId: event.folderId,
        query: event.query
      );
      developer.log('Loaded ${documents.length} documents', name: 'DocumentBloc');
      emit(DocumentsLoaded(documents));
    } catch (error) {
      LoggerUtil.error('Failed to load documents: $error');
      emit(DocumentError('Failed to load documents: $error'));
    }
  }

  Future<void> _onLoadDocument(LoadDocument event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentLoading());
      final document = await _documentRepository.getDocument(event.id);
      emit(DocumentLoaded(document));
    } catch (error) {
      LoggerUtil.error('Failed to load document: $error');
      emit(DocumentError('Failed to load document: $error'));
    }
  }

  Future<void> _onCreateDocument(CreateDocument event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      final document = await _documentRepository.createContentDocument(
        name: event.name,
        folderId: event.folderId,
        content: event.content
      );
      
      // Re-fetch the documents to update the list
      final documents = await _documentRepository.getDocuments(
        folderId: event.folderId
      );
      
      emit(DocumentCreated(document));
      emit(DocumentsLoaded(documents));
      emit(const DocumentOperationSuccess('Document created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create document: $error');
      emit(DocumentError('Failed to create document: $error'));
    }
  }

  Future<void> _onAddDocument(AddDocument event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      final document = await _documentRepository.createDocument(
        event.folderId ?? '', 
        event.file, 
        event.name
      );
      
      // Re-fetch the documents to update the list
      final documents = await _documentRepository.getDocuments(
        folderId: event.folderId
      );
      
      emit(DocumentCreated(document));
      emit(DocumentsLoaded(documents));
      emit(const DocumentOperationSuccess('Document created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create document: $error');
      emit(DocumentError('Failed to create document: $error'));
    }
  }

  Future<void> _onUpdateDocument(UpdateDocument event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      
      // Handle nullable parameters properly
      final result = await _documentRepository.updateDocument(
        event.id,
        event.folderId ?? "",  // Use empty string as a fallback
        event.file,  // Repository should handle null file
        event.name ?? "",  // Use empty string as a fallback
        content: event.content
      );
      
      // Re-fetch the single document to show updated version
      final document = await _documentRepository.getDocument(event.id);
      
      // Re-fetch all documents if we have a folder ID
      if (event.folderId != null) {
        final documents = await _documentRepository.getDocuments(
          folderId: event.folderId
        );
        emit(DocumentsLoaded(documents));
      }
      
      emit(DocumentUpdated(result));
      emit(DocumentLoaded(document));
      emit(const DocumentOperationSuccess('Document updated successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to update document: $error');
      emit(DocumentError('Failed to update document: $error'));
    }
  }

  Future<void> _onDeleteDocument(DeleteDocument event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      final result = await _documentRepository.deleteDocument(event.id);
      
      // Re-fetch the documents if we have a folder ID
      if (event.folderId != null) {
        final documents = await _documentRepository.getDocuments(
          folderId: event.folderId
        );
        emit(DocumentsLoaded(documents));
      }
      
      emit(DocumentDeleted(result));
      emit(const DocumentOperationSuccess('Document deleted successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to delete document: $error');
      emit(DocumentError('Failed to delete document: $error'));
    }
  }
  
  Future<void> _onRestoreVersion(RestoreVersion event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      final result = await _documentRepository.restoreVersion(
        event.documentId,
        event.versionId
      );
      
      // Re-fetch the single document to show updated version
      final document = await _documentRepository.getDocument(event.documentId);
      
      emit(DocumentVersionRestored(result));
      emit(DocumentLoaded(document));
      emit(const DocumentOperationSuccess('Document version restored successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to restore document version: $error');
      emit(DocumentError('Failed to restore document version: $error'));
    }
  }
} 
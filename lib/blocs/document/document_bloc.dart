import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/blocs/document/document_state.dart';
import 'package:doc_manager/repository/document_repository.dart';
import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/shared/utils/logger.dart';
import 'package:doc_manager/shared/utils/app_logger.dart';
import 'dart:developer' as developer;

class DocumentBloc extends Bloc<DocumentEvent, DocumentState> {
  final DocumentRepository _documentRepository;

  DocumentBloc({required DocumentRepository documentRepository}) 
    : _documentRepository = documentRepository,
      super(const DocumentInitial()) {
    on<LoadDocuments>(_onLoadDocuments);
    on<LoadDocument>(_onLoadDocument);
    on<AddDocument>(_onAddDocument);
    on<AddDocumentFromBytes>(_onAddDocumentFromBytes);
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
      
      // Perform all operations
      final document = await _documentRepository.createContentDocument(
        event.folderId,
        event.name,
        event.content ?? ''
      );
      
      final documents = await _documentRepository.getDocuments(
        folderId: event.folderId
      );
      
      // Emit single combined state
      emit(DocumentCreatedWithList(document: document, documents: documents));
      
    } catch (error) {
      AppLogger.error('Failed to create document', name: 'DocumentBloc', error: error);
      emit(DocumentError('Failed to create document: $error'));
    }
  }

  Future<void> _onAddDocument(AddDocument event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      
      // Perform all operations
      final document = await _documentRepository.createDocument(
        event.folderId ?? '', 
        event.file, 
        event.name
      );
      
      final documents = await _documentRepository.getDocuments(
        folderId: event.folderId
      );
      
      // Emit single combined state
      emit(DocumentCreatedWithList(document: document, documents: documents));
      
    } catch (error) {
      AppLogger.error('Failed to create document', name: 'DocumentBloc', error: error);
      emit(DocumentError('Failed to create document: $error'));
    }
  }

  Future<void> _onAddDocumentFromBytes(AddDocumentFromBytes event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      
      // Perform all operations
      final document = await _documentRepository.createDocumentFromBytes(
        event.folderId ?? '', 
        event.fileBytes,
        event.fileName,
        event.name
      );
      
      final documents = await _documentRepository.getDocuments(
        folderId: event.folderId
      );
      
      // Emit single combined state
      emit(DocumentCreatedWithList(document: document, documents: documents));
      
    } catch (error) {
      AppLogger.error('Failed to create document from bytes', name: 'DocumentBloc', error: error);
      emit(DocumentError('Failed to create document: $error'));
    }
  }

  Future<void> _onUpdateDocument(UpdateDocument event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      
      // Validate required parameters
      if (event.id.isEmpty) {
        emit(const DocumentError('Document ID is required for update'));
        return;
      }
      
      if (event.name?.trim().isEmpty ?? true) {
        emit(const DocumentError('Document name cannot be empty'));
        return;
      }
      
      // Use null values instead of empty strings
      final result = await _documentRepository.updateDocument(
        event.id,
        event.folderId?.isNotEmpty == true ? event.folderId! : null,
        event.file,
        event.name!.trim(),
        content: event.content?.isNotEmpty == true ? event.content : null,
      );
      
      // Re-fetch the single document to show updated version
      final document = await _documentRepository.getDocument(event.id);
      
      // Re-fetch all documents if we have a folder ID
      List<Document>? documents;
      if (event.folderId != null) {
        documents = await _documentRepository.getDocuments(
          folderId: event.folderId
        );
      }
      
      // Emit single combined state
      emit(DocumentUpdatedWithList(
        updateResult: result,
        document: document,
        documents: documents,
      ));
      
    } catch (error) {
      AppLogger.error('Failed to update document', name: 'DocumentBloc', error: error);
      emit(DocumentError('Failed to update document: $error'));
    }
  }

  Future<void> _onDeleteDocument(DeleteDocument event, Emitter<DocumentState> emit) async {
    try {
      // Get current documents from state before making the delete request
      List<Document> currentDocuments = [];
      if (state is DocumentsLoaded) {
        currentDocuments = (state as DocumentsLoaded).documents;
      }
      
      emit(const DocumentsLoading());
      final result = await _documentRepository.deleteDocument(event.id);
      
      // Instead of reloading from server, remove the deleted document from current state
      final updatedDocuments = currentDocuments
          .where((doc) => doc.id != event.id)
          .toList();
      
      // Emit optimized state with document removed from local list
      emit(DocumentDeletedWithList(
        deleteResult: result,
        documents: updatedDocuments,
      ));
      
    } catch (error) {
      AppLogger.error('Failed to delete document', name: 'DocumentBloc', error: error);
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
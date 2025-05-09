import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/blocs/document/document_state.dart';
import 'package:doc_manager/repository/document_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class DocumentBloc extends Bloc<DocumentEvent, DocumentState> {
  final DocumentRepository _documentRepository;

  DocumentBloc({required DocumentRepository documentRepository}) 
    : _documentRepository = documentRepository,
      super(const DocumentInitial()) {
    on<LoadDocuments>(_onLoadDocuments);
    on<LoadDocument>(_onLoadDocument);
    on<AddDocument>(_onAddDocument);
    on<UpdateDocument>(_onUpdateDocument);
    on<DeleteDocument>(_onDeleteDocument);
  }

  Future<void> _onLoadDocuments(LoadDocuments event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      final documents = await _documentRepository.getDocuments();
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

  Future<void> _onAddDocument(AddDocument event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      final document = await _documentRepository.createDocument(
        event.folderId, 
        event.file, 
        event.name
      );
      emit(DocumentLoaded(document));
      emit(const DocumentOperationSuccess('Document created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create document: $error');
      emit(DocumentError('Failed to create document: $error'));
    }
  }

  Future<void> _onUpdateDocument(UpdateDocument event, Emitter<DocumentState> emit) async {
    try {
      emit(const DocumentsLoading());
      final result = await _documentRepository.updateDocument(
        event.id,
        event.folderId, 
        event.file, 
        event.name
      );
      emit(DocumentUpdated(result));
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
      emit(DocumentDeleted(result));
      emit(const DocumentOperationSuccess('Document deleted successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to delete document: $error');
      emit(DocumentError('Failed to delete document: $error'));
    }
  }
} 
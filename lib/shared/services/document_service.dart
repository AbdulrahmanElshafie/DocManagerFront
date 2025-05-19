import 'dart:io';
import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/repository/document_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';
import 'package:path/path.dart' as path;

class DocumentService {
  static final DocumentService _instance = DocumentService._internal();
  final DocumentRepository _documentRepository;

  // Private constructor
  DocumentService._internal() : _documentRepository = DocumentRepository();

  // Singleton instance
  factory DocumentService() {
    return _instance;
  }

  /// Get all documents
  Future<List<Document>> getAllDocuments() async {
    try {
      return await _documentRepository.getDocuments();
    } catch (e) {
      LoggerUtil.error('Error fetching documents', e);
      rethrow;
    }
  }

  /// Get document by ID
  Future<Document> getDocumentById(String id) async {
    try {
      return await _documentRepository.getDocument(id);
    } catch (e) {
      LoggerUtil.error('Error fetching document: $id', e);
      rethrow;
    }
  }

  /// Create new document
  Future<Document> createDocument(String folderId, File file, String name) async {
    try {
      return await _documentRepository.createDocument(folderId, file, name);
    } catch (e) {
      LoggerUtil.error('Error creating document', e);
      rethrow;
    }
  }

  /// Update existing document
  Future<Map<String, dynamic>> updateDocument(String id, String folderId, File file, String name) async {
    try {
      return await _documentRepository.updateDocument(id, folderId, file, name);
    } catch (e) {
      LoggerUtil.error('Error updating document: $id', e);
      rethrow;
    }
  }

  /// Delete document
  Future<Map<String, dynamic>> deleteDocument(String id) async {
    try {
      return await _documentRepository.deleteDocument(id);
    } catch (e) {
      LoggerUtil.error('Error deleting document: $id', e);
      rethrow;
    }
  }

  /// Parse document file type
  DocumentType parseDocumentType(String filePath) {
    try {
      // Use path.extension to correctly extract the file extension
      final extension = path.extension(filePath).toLowerCase().replaceAll('.', '');
      LoggerUtil.info("Parsed file extension: $extension from path: $filePath");
      
      if (['txt', 'doc', 'docx', 'rtf'].contains(extension)) {
        return DocumentType.docx;
      } else if (extension == 'csv') {
        return DocumentType.csv;
      } else if (extension == 'pdf') {
        return DocumentType.pdf;
      } else {
        LoggerUtil.warning('Unknown document type for extension: $extension');
        // If we can't determine the type, let's use the unsupported type
        return DocumentType.unsupported;
      }
    } catch (e) {
      LoggerUtil.error('Error parsing document type: $e');
      return DocumentType.unsupported;
    }
  }
} 
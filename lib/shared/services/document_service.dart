import 'dart:io';
import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/repository/document_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

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
    // Extract extension from filename
    final String extension;
    if (filePath.contains('.')) {
      extension = filePath.split('.').last.toLowerCase();
    } else {
      LoggerUtil.warning('No file extension found in path: $filePath, defaulting to PDF');
      return DocumentType.pdf;
    }
    
    // Word document formats
    if (['doc', 'docx', 'rtf', 'dot', 'dotx', 'odt'].contains(extension)) {
      return DocumentType.docx;
    } 
    // PDF format
    else if (extension == 'pdf') {
      return DocumentType.pdf;
    } 
    // Spreadsheet formats
    else if (['csv', 'xls', 'xlsx', 'xlsm', 'ods'].contains(extension)) {
      return DocumentType.csv;
    } 
    else {
      LoggerUtil.warning('Unknown document type for extension: $extension, defaulting to type based on content analysis');
      
      // Try to determine the type based on the filename
      final lowerFilePath = filePath.toLowerCase();
      if (lowerFilePath.contains('spreadsheet') || lowerFilePath.contains('excel') || lowerFilePath.contains('csv')) {
        return DocumentType.csv;
      } else if (lowerFilePath.contains('word') || lowerFilePath.contains('doc') || lowerFilePath.contains('text')) {
        return DocumentType.docx;
      } else {
        LoggerUtil.warning('Could not determine document type, defaulting to PDF');
        return DocumentType.pdf;
      }
    }
  }
} 
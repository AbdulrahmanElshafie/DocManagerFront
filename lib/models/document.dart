import 'dart:io' as io show File;
import 'package:equatable/equatable.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import '../shared/utils/file_utils.dart';
import '../shared/network/api.dart';
import 'validation_result.dart';

enum DocumentType {
  pdf,
  csv,
  docx,
  unsupported
}

class Document extends Equatable {
  final String id;
  final String name;
  final io.File? file;
  final String? filePath;
  final String? fileUrl;
  final DocumentType type;
  final String folderId;
  final String ownerId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Document({
    required this.id,
    required this.name,
    this.file,
    this.filePath,
    this.fileUrl,
    required this.type,
    required this.folderId,
    required this.ownerId,
    required this.createdAt,
    this.updatedAt,
  });

  // Platform-aware file path validator
  static bool _isValidFilePath(String? path) {
    if (path == null || path.isEmpty || path.trim() == 'path') {
      return false;
    }
    
    if (kIsWeb) {
      // For web, accept URLs and basic validation
      return path.startsWith('http') || path.startsWith('blob:') || path.isNotEmpty;
    } else {
      // For mobile/desktop, validate actual file paths
      try {
        final normalizedPath = path.replaceAll('\\', '/');
        return normalizedPath.isNotEmpty && !normalizedPath.contains('//');
      } catch (e) {
        return false;
      }
    }
  }

  // Simplified fromJson method
  factory Document.fromJson(Map<String, dynamic> json) {
    developer.log('Parsing document JSON: $json', name: 'Document.fromJson');
    
    // Validate input data
    final validation = Document.validateDocument(json);
    if (!validation.isValid) {
      developer.log('Document validation failed: ${validation.errors}', name: 'Document.fromJson');
      // Continue with defaults but log the issues
    }
    
    io.File? fileObj;
    String? filePathStr;
    
    // Extract file path from JSON
    if (json['file'] != null) {
      filePathStr = json['file'] is String ? json['file'] : null;
      
      // Validate file path
      if (_isValidFilePath(filePathStr)) {
        // Normalize path for non-web platforms
        if (!kIsWeb && filePathStr != null) {
          filePathStr = filePathStr.replaceAll('\\', '/');
          try {
            fileObj = io.File(filePathStr);
          } catch (e) {
            developer.log('Could not create File object: $e', name: 'Document.fromJson');
            fileObj = null;
          }
        }
      } else {
        developer.log('Invalid file path: $filePathStr', name: 'Document.fromJson');
        filePathStr = null;
      }
    }
    
    // First check the explicit type from the JSON
    DocumentType docType = _parseDocumentType(json['type']);
    
    // Then try to infer from the file path if available
    if (docType == DocumentType.unsupported && filePathStr != null) {
      docType = _inferTypeFromPath(filePathStr);
    }
    
    // Finally, try to infer from the name as a last resort
    if (docType == DocumentType.unsupported && json['name'] != null) {
      docType = _inferTypeFromPath(json['name']);
    }
    
    return Document(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? 'Unnamed Document',
      file: fileObj,
      filePath: filePathStr,
      fileUrl: json['file_url'],
      ownerId: json['owner']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      folderId: json['folder']?.toString() ?? '',
      type: docType,
    );
  }

  // File validation method
  bool hasValidFile() {
    if (kIsWeb) {
      return fileUrl != null && fileUrl!.isNotEmpty;
    } else {
      return file != null && FileUtils.existsSync(file!);
    }
  }

  // Validation methods for Document
  static ValidationResult validateDocument(Map<String, dynamic> json) {
    final errors = <String>[];
    
    if (json['id'] == null || json['id'].toString().isEmpty) {
      errors.add('Document ID is required');
    }
    
    if (json['name'] == null || json['name'].toString().trim().isEmpty) {
      errors.add('Document name is required');
    }
    
    if (json['owner'] == null || json['owner'].toString().isEmpty) {
      errors.add('Document owner is required');
    }
    
    if (json['folder'] == null || json['folder'].toString().isEmpty) {
      errors.add('Document folder is required');
    }
    
    if (json['created_at'] == null) {
      errors.add('Document creation date is required');
    } else {
      try {
        DateTime.parse(json['created_at']);
      } catch (e) {
        errors.add('Invalid creation date format');
      }
    }
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
  
  bool get isValid {
    return id.isNotEmpty && 
           name.trim().isNotEmpty && 
           ownerId.isNotEmpty && 
           folderId.isNotEmpty;
  }

  static DocumentType _parseDocumentType(String? typeStr) {
    if (typeStr == null) return DocumentType.unsupported;
    
    switch(typeStr.toLowerCase()) {
      case 'csv':
        return DocumentType.csv;
      case 'docx':
      case 'doc':
      case 'rtf':
      case 'txt':
        return DocumentType.docx;
      case 'pdf':
        return DocumentType.pdf;
      default:
        return DocumentType.unsupported;
    }
  }

  // Helper method to infer document type from file path
  static DocumentType _inferTypeFromPath(String filePath) {
    try {
      final extension = path.extension(filePath).toLowerCase().replaceAll('.', '');
      
      if (['csv'].contains(extension)) {
        return DocumentType.csv;
      } else if (['pdf'].contains(extension)) {
        return DocumentType.pdf;
      } else if (['doc', 'docx', 'rtf', 'txt'].contains(extension)) {
        return DocumentType.docx;
      } else {
        developer.log('Could not infer type from extension: $extension', name: 'Document._inferTypeFromPath');
        return DocumentType.unsupported;
      }
    } catch (e) {
      developer.log('Error inferring file type: $e', name: 'Document._inferTypeFromPath');
      return DocumentType.unsupported;
    }
  }

  // Helper method to get absolute file URL
  String? getAbsoluteFileUrl() {
    if (fileUrl != null && fileUrl!.isNotEmpty) {
      if (fileUrl!.startsWith('http')) {
        return fileUrl;
      } else {
        // Construct absolute URL from relative path
        return '${API.baseUrl.replaceAll('/api', '')}$fileUrl';
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'file': filePath ?? FileUtils.getFilePath(file),
    'owner': ownerId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'folder': folderId,
    'type': type.toString().split('.').last,
  };

  Document copyWith({
    String? id,
    String? name,
    io.File? file,
    String? filePath,
    String? fileUrl,
    DocumentType? type,
    String? folderId,
    String? ownerId,
    DateTime? createdAt,
    DateTime? lastModified,
    DateTime? updatedAt,
    int? size,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      file: file ?? this.file,
      filePath: filePath ?? this.filePath,
      fileUrl: fileUrl ?? this.fileUrl,
      type: type ?? this.type,
      folderId: folderId ?? this.folderId,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Factory method to create an empty document
  factory Document.empty({
    required String name,
    required DocumentType type,
    required String folderId,
  }) {
    return Document(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID
      name: name,
      type: type,
      folderId: folderId,
      ownerId: '', // Will be set by the server
      createdAt: DateTime.now(),
    );
  }

  // Factory method to create a completely empty document
  factory Document.emptyDefault() {
    return Document(
      id: '',
      name: '',
      type: DocumentType.unsupported,
      folderId: '',
      ownerId: '',
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        file,
        filePath,
        fileUrl,
        type,
        folderId,
        ownerId,
        createdAt,
        updatedAt,
      ];
} 
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;

enum DocumentType {
  pdf,
  csv,
  docx,
  unsupported
}

class Document extends Equatable {
  final String id;
  final String name;
  late File? file;
  final String? filePath;
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
    required this.type,
    required this.folderId,
    required this.ownerId,
    required this.createdAt,
    this.updatedAt,
  });


  factory Document.fromJson(Map<String, dynamic> json) {
    developer.log('Parsing document JSON: $json', name: 'Document.fromJson');
    
    File? fileObj;
    String? filePathStr;

    if (json['file'] != null) {
      try {
        // Get the file path from the API response
        final filePath = json['file'];
        filePathStr = filePath is String ? filePath : null;
        
        // Only create a File object if we're not on web and path is valid
        if (!kIsWeb && filePathStr != null && filePathStr.isNotEmpty) {
          try {
            // Normalize the file path for Windows
            if (Platform.isWindows) {
              filePathStr = filePathStr.replaceAll('\\', '/');
            }
            
            // Ensure the path isn't just the string "path" which can happen in error cases
            if (filePathStr == "path" || filePathStr.trim().isEmpty) {
              developer.log('Invalid file path received: $filePathStr', name: 'Document.fromJson');
              filePathStr = null;
            } else {
              fileObj = File(filePathStr);
              // Check if file exists to validate path - but don't throw if it doesn't
              if (!fileObj.existsSync()) {
                developer.log('File does not exist at path: $filePathStr', name: 'Document.fromJson');
                // We'll still keep the fileObj and path, as it might be created later
              }
            }
          } catch (e) {
            developer.log('Error creating File object: $e', name: 'Document.fromJson');
            fileObj = null;
          }
        }
      } catch (e) {
        developer.log('Error handling file path: $e', name: 'Document.fromJson');
      }
    }
    
    // First check the explicit type from the JSON
    DocumentType docType = _parseDocumentType(json['type']);
    
    // Then try to infer from the file path if available
    if ((docType == DocumentType.unsupported || docType == null) && filePathStr != null) {
      docType = _inferTypeFromPath(filePathStr);
    }
    
    // Finally, try to infer from the name as a last resort
    if ((docType == DocumentType.unsupported || docType == null) && json['name'] != null) {
      docType = _inferTypeFromPath(json['name']);
    }
    
    return Document(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      file: fileObj,
      filePath: filePathStr,
      ownerId: json['owner']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      folderId: json['folder']?.toString() ?? '',
      type: docType,
    );
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'file': filePath ?? file?.path,
    'owner': ownerId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'folder': folderId,
    'type': type.toString().split('.').last,
  };

  Document copyWith({
    String? id,
    String? name,
    File? file,
    String? filePath,
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
        type,
        folderId,
        ownerId,
        createdAt,
        updatedAt,
      ];
} 
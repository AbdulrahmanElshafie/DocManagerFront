import 'dart:io';
import 'package:equatable/equatable.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;

enum DocumentType {
  pdf,
  csv,
  docx,
}

class Document extends Equatable {
  final String id;
  final String name;
  final File? file;
  final String? filePath;
  final DocumentType type;
  final String folderId;
  final String ownerId;
  final DateTime createdAt;
  final DateTime? lastModified;
  final DateTime? updatedAt;
  final int size;
  final String? content;


  const Document({
    required this.id,
    required this.name,
    this.file,
    this.filePath,
    required this.type,
    required this.folderId,
    required this.ownerId,
    required this.createdAt,
    this.lastModified,
    this.updatedAt,
    required this.size,
    this.content,
  });


  factory Document.fromJson(Map<String, dynamic> json) {
    developer.log('Parsing document JSON: $json', name: 'Document.fromJson');
    
    int fileSize = 0;
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
            fileObj = File(filePathStr);
            fileSize = fileObj.existsSync() ? fileObj.lengthSync() : 0;
          } catch (e) {
            developer.log('Error creating File object: $e', name: 'Document.fromJson');
            fileObj = null;
          }
        }
      } catch (e) {
        developer.log('Error handling file path: $e', name: 'Document.fromJson');
      }
    }
    
    return Document(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      file: fileObj,
      filePath: filePathStr,
      ownerId: json['owner'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      lastModified: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      folderId: json['folder'] ?? '',
      content: json['content'],
      type: _parseDocumentType(json['type']),
      size: fileSize,
    );
  }

  static DocumentType _parseDocumentType(String? typeStr) {
    if (typeStr == null) return DocumentType.pdf; // Default to PDF
    
    switch(typeStr.toLowerCase()) {
      case 'csv':
        return DocumentType.csv;
      case 'docx':
        return DocumentType.docx;
      case 'pdf':
      default:
        return DocumentType.pdf;
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
    'content': content,
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
    String? content,
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
      lastModified: lastModified ?? this.lastModified,
      updatedAt: updatedAt ?? this.updatedAt,
      size: size ?? this.size,
      content: content ?? this.content,
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
      size: 0,
      content: '',
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
        lastModified,
        updatedAt,
        size,
        content,
      ];
} 
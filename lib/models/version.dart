import 'dart:io' if (dart.library.html) 'dart:html';
import 'dart:io' as io show File;
import 'package:doc_manager/models/document.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../shared/utils/file_utils.dart';

class Version extends Document {
  final String versionId;
  final String modifiedBy;
  final String? comment;
  final int versionNumber;
  final DateTime? lastModified;
  final int size;

  Version({
    required this.modifiedBy,
    required this.versionId,
    this.comment,
    required this.versionNumber,
    required super.id,
    required super.name,
    super.file,
    super.filePath,
    required super.type,
    required super.folderId,
    required super.ownerId,
    required super.createdAt,
    super.updatedAt,
    this.lastModified,
    this.size = 0,
  });

  factory Version.fromJson(Map<String, dynamic> json) {
    io.File? fileObj;
    String? filePathStr;
    
    if (json['file'] != null) {
      final filePath = json['file'];
      filePathStr = filePath is String ? filePath : null;
      
      // Only create a File object if we're not on web and path is valid
      if (!kIsWeb && filePathStr != null && filePathStr.isNotEmpty) {
        try {
          io.File? newFileObj;
          if (!kIsWeb) {
            newFileObj = io.File(filePathStr);
          }
          fileObj = newFileObj;
        } catch (e) {
          print('Error creating File object: $e');
        }
      }
    }
    
    // Extract the lastModified date and size
    DateTime? lastModified;
    if (json['lastModified'] != null) {
      lastModified = DateTime.parse(json['lastModified']);
    } else if (json['updated_at'] != null) {
      lastModified = DateTime.parse(json['updated_at']);
    }
    
    int size = json['size'] ?? 0;
    
    return Version(
      id: json['id'],
      name: json['name'],
      file: fileObj,
      filePath: filePathStr,
      type: _parseDocumentType(json['type']),
      folderId: json['folderId'] ?? json['folder'],
      ownerId: json['ownerId'] ?? json['owner'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : 
                 json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : 
                json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      lastModified: lastModified,
      size: size,
      versionId: json['versionId'] ?? json['version_id'] ?? '',
      modifiedBy: json['modifiedBy'] ?? json['modified_by'] ?? '',
      comment: json['comment'],
      versionNumber: json['versionNumber'] ?? json['version_number'] ?? 1,
    );
  }

  static DocumentType _parseDocumentType(dynamic typeStr) {
    if (typeStr == null) return DocumentType.pdf; // Default to PDF
    
    if (typeStr is String) {
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
    return DocumentType.pdf; // Default fallback
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'versionId': versionId,
    'modifiedBy': modifiedBy,
    'comment': comment,
    'versionNumber': versionNumber,
    'lastModified': lastModified?.toIso8601String(),
    'size': size,
  };

  @override
  Version copyWith({
    String? id,
    String? name,
    io.File? file,
    String? filePath,
    DocumentType? type,
    String? folderId,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastModified,
    int? size,
    String? comment,
    String? modifiedBy,
    String? versionId,
    int? versionNumber,
  }) {
    return Version(
      id: id ?? this.id,
      name: name ?? this.name,
      file: file ?? this.file,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      folderId: folderId ?? this.folderId,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModified: lastModified ?? this.lastModified,
      size: size ?? this.size,
      comment: comment ?? this.comment,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      versionId: versionId ?? this.versionId,
      versionNumber: versionNumber ?? this.versionNumber,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        versionId,
        modifiedBy,
        comment,
        versionNumber,
        lastModified,
        size,
      ];
}
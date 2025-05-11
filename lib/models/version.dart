import 'dart:io';
import 'package:doc_manager/models/document.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class Version extends Document {
  final String versionId;
  final String modifiedBy;
  final String? comment;
  final int versionNumber;

  const Version({
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
    super.lastModified,
    super.updatedAt,
    required super.size,
    super.content,
  });

  factory Version.fromJson(Map<String, dynamic> json) {
    File? fileObj;
    String? filePathStr;
    
    if (json['file'] != null) {
      final filePath = json['file'];
      filePathStr = filePath is String ? filePath : null;
      
      // Only create a File object if we're not on web and path is valid
      if (!kIsWeb && filePathStr != null && filePathStr.isNotEmpty) {
        try {
          fileObj = File(filePathStr);
        } catch (e) {
          print('Error creating File object: $e');
        }
      }
    }
    
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
      lastModified: json['lastModified'] != null ? DateTime.parse(json['lastModified']) : 
                   json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : 
                json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      size: json['size'] ?? 0,
      versionId: json['versionId'] ?? json['version_id'] ?? '',
      modifiedBy: json['modifiedBy'] ?? json['modified_by'] ?? '',
      comment: json['comment'],
      versionNumber: json['versionNumber'] ?? json['version_number'] ?? 1,
      content: json['content'],
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
  };

  @override
  Version copyWith({
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
      lastModified: lastModified ?? this.lastModified,
      updatedAt: updatedAt ?? this.updatedAt,
      size: size ?? this.size,
      content: content ?? this.content,
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
      ];
}
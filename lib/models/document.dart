import 'dart:io';

import 'package:equatable/equatable.dart';

enum DocumentType {
  text,
  pdf,
  image,
}

class Document extends Equatable {
  final String id;
  final String name;
  final File file;
  final DocumentType type;
  final String folderId;
  final String ownerId;
  final DateTime createdAt;
  final DateTime? lastModified;
  final int size;


  const Document({
    required this.id,
    required this.name,
    required this.file,
    required this.type,
    required this.folderId,
    required this.ownerId,
    required this.createdAt,
    required this.lastModified,
    required this.size
  });


  factory Document.fromJson(Map<String, dynamic> json) => Document(
    id: json['id'],
    name: json['name'],
    file: json['file'],
    ownerId: json['owner'],
    createdAt: DateTime.parse(json['created_at']),
    lastModified: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    folderId: json['folderId'],
    type: DocumentType.values.firstWhere(
        (e) => e.toString() == "DocumentType"
    ),
    size: File(json['file']).lengthSync(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': name,
    'file': file,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'lastModified': lastModified?.toIso8601String(),
    'folderId': folderId,
  };

  Document copyWith({
    String? id,
    String? name,
    File? file,
    DocumentType? type,
    String? folderId,
    String? ownerId,
    DateTime? createdAt,
    DateTime? lastModified,
    int? size,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      file: file ?? this.file,
      type: type ?? this.type,
      folderId: folderId ?? this.folderId,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      size: size ?? this.size,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        file,
        type,
        folderId,
        ownerId,
        createdAt,
        lastModified,
        size,
      ];

} 
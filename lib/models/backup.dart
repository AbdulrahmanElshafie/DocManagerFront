import 'package:equatable/equatable.dart';

class Backup extends Equatable {
  final String id;
  final String? documentId;  // Optional - API may not return this
  final DateTime createdAt;
  final String? filePath;    // File URL from API

  const Backup({
    required this.id,
    this.documentId,
    required this.createdAt,
    this.filePath,
  });

  factory Backup.fromJson(Map<String, dynamic> json) => Backup(
    id: json['id'] ?? '',
    // Recognize document_id or document as keys
    documentId: json['document_id'] ?? json['document'] ?? json['documentId'],
    createdAt: json['created_at'] != null 
               ? DateTime.parse(json['created_at'])
               : (json['createdAt'] != null 
                  ? DateTime.parse(json['createdAt'])
                  : DateTime.now()),
    filePath: json['file']
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'document_id': documentId,
    'created_at': createdAt.toIso8601String(),
    'file': filePath,
  };

  Backup copyWith({
    String? id,
    String? documentId,
    DateTime? createdAt,
    String? filePath,
  }) {
    return Backup(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      createdAt: createdAt ?? this.createdAt,
      filePath: filePath ?? this.filePath,
    );
  }

  @override
  List<Object?> get props => [
    id,
    documentId,
    createdAt,
    filePath,
  ];
}
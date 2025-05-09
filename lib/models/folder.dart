import 'package:equatable/equatable.dart';

class Folder extends Equatable {
  final String id;
  final String name;
  final String? parentId;
  final String ownerId;
  final DateTime createdAt;
  final DateTime lastModified;
  final List<String> documentIds;
  final List<String> folderIds;

  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    required this.ownerId,
    required this.createdAt,
    required this.lastModified,
    required this.documentIds,
    required this.folderIds,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    id: json['id'],
    name: json['name'],
    parentId: json['parent'],
    ownerId: json['owner'],
    createdAt: DateTime.parse(json['created_at']),
    documentIds: List<String>.from(json['documentIds'] ?? []),
    lastModified: DateTime.parse(json['updated_at']),
    folderIds: List<String>.from(json['folderIds'] ?? []),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'documentIds': documentIds,
    'lastModified': lastModified.toIso8601String(),
    'folderIds': folderIds
  };

  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    String? ownerId,
    DateTime? createdAt,
    DateTime? lastModified,
    List<String>? documentIds,
    List<String>? folderIds
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      documentIds: documentIds ?? this.documentIds,
      folderIds: folderIds ?? this.folderIds
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        parentId,
        ownerId,
        createdAt,
        lastModified,
        documentIds,
        folderIds
      ];
} 
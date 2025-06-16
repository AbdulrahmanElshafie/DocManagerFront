import 'package:equatable/equatable.dart';
import 'dart:developer' as developer;

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

  factory Folder.fromJson(Map<String, dynamic> json) {
    developer.log('Parsing folder JSON: $json', name: 'Folder.fromJson');
    
    // Parse nested document and folder lists if they exist
    List<String> documentIds = [];
    List<String> folderIds = [];
    
    // API provides 'documents' and 'folders' as string values that need parsing
    if (json['documents'] != null) {
      if (json['documents'] is List) {
        try {
          documentIds = (json['documents'] as List)
              .map((doc) => doc is Map<String, dynamic> ? doc['id'].toString() : doc.toString())
              .toList();
        } catch (e) {
          developer.log('Error parsing documentIds from list: $e', name: 'Folder.fromJson');
        }
      } else if (json['documents'] is String) {
        try {
          final docString = json['documents'] as String;
          if (docString.isNotEmpty) {
            documentIds = docString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          }
        } catch (e) {
          developer.log('Error parsing documentIds from string: $e', name: 'Folder.fromJson');
        }
      }
    }
    
    if (json['folders'] != null) {
      if (json['folders'] is List) {
        try {
          folderIds = (json['folders'] as List)
              .map((folder) => folder is Map<String, dynamic> ? folder['id'].toString() : folder.toString())
              .toList();
        } catch (e) {
          developer.log('Error parsing folderIds from list: $e', name: 'Folder.fromJson');
        }
      } else if (json['folders'] is String) {
        try {
          final folderString = json['folders'] as String;
          if (folderString.isNotEmpty) {
            folderIds = folderString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          }
        } catch (e) {
          developer.log('Error parsing folderIds from string: $e', name: 'Folder.fromJson');
        }
      }
    }
    
    return Folder(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      parentId: json['parent']?.toString(),
      ownerId: json['owner']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      lastModified: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      documentIds: documentIds,
      folderIds: folderIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parent': parentId,
    'owner': ownerId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': lastModified.toIso8601String(),
    'documents': documentIds,
    'folders': folderIds
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

  // Factory method to create an empty folder
  factory Folder.empty() {
    return Folder(
      id: '',
      name: '',
      parentId: null,
      ownerId: '',
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      documentIds: [],
      folderIds: [],
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
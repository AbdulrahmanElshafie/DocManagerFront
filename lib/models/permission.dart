import 'package:equatable/equatable.dart';

class Permission extends Equatable {
  final String id;
  final String userId;
  final String documentId;
  final String folderId;
  final String level;
  final String permissionType;

  const Permission({
    required this.id,
    required this.userId,
    required this.documentId,
    required this.folderId,
    required this.level,
    required this.permissionType,
  });

  factory Permission.fromJson(Map<String, dynamic> json) => Permission(
    id: json['id'],
    userId: json['userId'],
    documentId: json['documentId'],
    folderId: json['folderId'],
    level: json['level'],
    permissionType: json['permissionType'] ?? 'read',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'documentId': documentId,
    'folderId': folderId,
    'level': level,
    'permissionType': permissionType,
  };

  Permission copyWith({
    String? id,
    String? userId,
    String? documentId,
    String? folderId,
    String? level,
    String? permissionType,
  }) {
    return Permission(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        documentId: documentId ?? this.documentId,
        folderId: folderId ?? this.folderId,
        level: level ?? this.level,
        permissionType: permissionType ?? this.permissionType,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    documentId,
    folderId,
    level,
    permissionType,
  ];
} 
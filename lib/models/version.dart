import 'dart:io';
import 'package:doc_manager/models/document.dart';

class Version extends Document {
  final String versionId;
  final String modifiedBy;
  final String? comment;

  const Version({
    required this.modifiedBy,
    required this.versionId,
    this.comment,
    required super.id,
    required super.name,
    required super.file,
    required super.type,
    required super.folderId,
    required super.ownerId,
    required super.createdAt,
    required super.lastModified,
    required super.size
  });

  factory Version.fromJson(Map<String, dynamic> json) => Version(
    id: json['id'],
    name: json['name'],
    file: json['file'],
    type: json['type'],
    folderId: json['folderId'],
    ownerId: json['ownerId'],
    createdAt: DateTime.parse(json['createdAt']),
    lastModified: DateTime.parse(json['lastModified']),
    size: json['size'],
    versionId: json['versionId'],
    modifiedBy: json['modifiedBy'],
    comment: json['comment'],
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'file': file,
    'type': type,
    'folderId': folderId,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'lastModified': lastModified?.toIso8601String(),
    'size': size,
    'versionId': versionId,
    'modifiedBy': modifiedBy,
    'comment': comment,
  };

  @override
  Version copyWith({
    String? id,
    File? file,
    DateTime? createdAt,
    String? comment,
    int? size,
    String? modifiedBy,
    String? versionId,
    String? name,
    DocumentType? type,
    String? folderId,
    String? ownerId,
    DateTime? lastModified
  }) {
    return Version(
      id: id ?? this.id,
      file: file ?? this.file,
      createdAt: createdAt ?? this.createdAt,
      comment: comment ?? this.comment,
      size: size ?? this.size,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      versionId: versionId ?? this.versionId,
      name: name ?? this.name,
      type: type ?? this.type,
      folderId: folderId ?? this.folderId,
      ownerId: ownerId ?? this.ownerId,
      lastModified: lastModified ?? this.lastModified
    );
  }

  @override
  List<Object?> get props => [
        id,
        file,
        createdAt,
        comment,
        size,
        modifiedBy,
        versionId,
        name,
        type,
        folderId,
        ownerId,
        lastModified
      ];
}
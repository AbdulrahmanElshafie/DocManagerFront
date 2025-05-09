import 'package:equatable/equatable.dart';

class ShareableLink extends Equatable {
  final String id;
  final String documentId;
  final String token;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final String createdBy;

  const ShareableLink({
    required this.id,
    required this.documentId,
    required this.token,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
    required this.createdBy
  });

  factory ShareableLink.fromJson(Map<String, dynamic> json) => ShareableLink(
    id: json['id'],
    documentId: json['documentId'],
      token: json['token'],
    createdAt: DateTime.parse(json['createdAt']),
    expiresAt: DateTime.parse(json['expiresAt']),
    isActive: json['isActive'],
    createdBy: json['createdBy']
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'toke': token,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'isActive': isActive,
    'createdBy': createdBy
  };

  ShareableLink copyWith({
    String? id,
    String? documentId,
    String? token,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    String? createdBy
  }) {
    return ShareableLink(
        id: id ?? this.id,
        documentId: documentId ?? this.documentId,
        token: token ?? this.token,
        createdAt: createdAt ?? this.createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
        isActive: isActive ?? this.isActive,
        createdBy: createdBy ?? this.createdBy
    );
  }

  @override
  List<Object?> get props => [
    id,
    documentId,
    token,
    createdAt,
    expiresAt,
    isActive,
    createdBy
  ];
}
import 'package:equatable/equatable.dart';

class Comment extends Equatable {
  final String id;
  final String documentId;
  final String content;
  final String userId;
  final String userName;
  final String? userAvatar;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.documentId,
    required this.content,
    required this.userId,
    this.userName = 'User', // Make optional with default value
    this.userAvatar,
    required this.createdAt,
    this.updatedAt,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      documentId: json['document'],
      content: json['content'],
      userId: json['user']?.toString() ?? json['user_details']?['id']?.toString() ?? '',
      userName: json['user_details']?['username'] ?? 'User',
      userAvatar: json['user_details']?['avatar'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      replies: json['replies'] != null
          ? (json['replies'] as List).map((e) => Comment.fromJson(e)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'document': documentId,
    'content': content,
    'user': userId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'replies': replies.map((e) => e.toJson()).toList(),
  };

  Comment copyWith({
    String? id,
    String? documentId,
    String? content,
    String? userId,
    String? userName,
    String? userAvatar,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      content: content ?? this.content,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      replies: replies ?? this.replies,
    );
  }

  @override
  List<Object?> get props => [
        id,
        documentId,
        content,
        userId,
        userName,
        userAvatar,
        createdAt,
        updatedAt,
        replies,
      ];
} 
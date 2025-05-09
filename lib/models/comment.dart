import 'package:equatable/equatable.dart';

class Comment extends Equatable {
  final String id;
  final String documentId;
  final String content;
  final String userId;
  final String userName;
  final String? userAvatar;
  final DateTime createdAt;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.documentId,
    required this.content,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.createdAt,
    this.replies = const [],
  });

  Comment copyWith({
    String? id,
    String? documentId,
    String? content,
    String? userId,
    String? userName,
    String? userAvatar,
    DateTime? createdAt,
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
        replies,
      ];
} 
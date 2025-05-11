import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/comment.dart';

abstract class CommentEvent extends Equatable {
  const CommentEvent();
  
  @override
  List<Object?> get props => [];
}

class GetComments extends CommentEvent {
  final String documentId;
  
  const GetComments({required this.documentId});
  
  @override
  List<Object?> get props => [documentId];
}

class LoadComments extends CommentEvent {
  final String documentId;
  
  const LoadComments(this.documentId);
  
  @override
  List<Object?> get props => [documentId];
}

class LoadComment extends CommentEvent {
  final String id;
  
  const LoadComment(this.id);
  
  @override
  List<Object?> get props => [id];
}

class CreateComment extends CommentEvent {
  final String documentId;
  final String content;
  final String? userId; // Make userId optional as the API might determine it from authentication
  
  const CreateComment({
    required this.documentId,
    required this.content,
    this.userId,
  });
  
  @override
  List<Object?> get props => [documentId, content, userId];
}

class UpdateComment extends CommentEvent {
  final String id;
  final String content;
  
  const UpdateComment({
    required this.id,
    required this.content
  });
  
  @override
  List<Object?> get props => [id, content];
}

class DeleteComment extends CommentEvent {
  final String id;
  
  const DeleteComment(this.id);
  
  @override
  List<Object?> get props => [id];
} 
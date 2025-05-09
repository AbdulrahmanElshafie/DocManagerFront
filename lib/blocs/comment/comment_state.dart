import 'package:equatable/equatable.dart';
import 'package:doc_manager/models/comment.dart';

abstract class CommentState extends Equatable {
  const CommentState();
  
  @override
  List<Object?> get props => [];
}

class CommentInitial extends CommentState {
  const CommentInitial();
}

class CommentsLoading extends CommentState {
  const CommentsLoading();
}

class CommentLoading extends CommentState {
  const CommentLoading();
}

class CommentsLoaded extends CommentState {
  final List<Comment> comments;
  
  const CommentsLoaded(this.comments);
  
  @override
  List<Object?> get props => [comments];
}

class CommentLoaded extends CommentState {
  final Comment comment;
  
  const CommentLoaded(this.comment);
  
  @override
  List<Object?> get props => [comment];
}

class CommentCreated extends CommentState {
  final Comment comment;
  
  const CommentCreated(this.comment);
  
  @override
  List<Object?> get props => [comment];
}

class CommentUpdated extends CommentState {
  final Map<String, dynamic> result;
  
  const CommentUpdated(this.result);
  
  @override
  List<Object?> get props => [result];
}

class CommentDeleted extends CommentState {
  final Map<String, dynamic> result;
  
  const CommentDeleted(this.result);
  
  @override
  List<Object?> get props => [result];
}

class CommentOperationSuccess extends CommentState {
  final String message;
  
  const CommentOperationSuccess(this.message);
  
  @override
  List<Object?> get props => [message];
}

class CommentError extends CommentState {
  final String error;
  
  const CommentError(this.error);
  
  @override
  List<Object?> get props => [error];
} 
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/comment/comment_event.dart';
import 'package:doc_manager/blocs/comment/comment_state.dart';
import 'package:doc_manager/repository/comment_repository.dart';
import 'package:doc_manager/shared/utils/logger.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  final CommentRepository _commentRepository;

  CommentBloc({required CommentRepository commentRepository})
      : _commentRepository = commentRepository,
        super(const CommentInitial()) {
    on<LoadComments>(_onLoadComments);
    on<LoadComment>(_onLoadComment);
    on<CreateComment>(_onCreateComment);
    on<UpdateComment>(_onUpdateComment);
    on<DeleteComment>(_onDeleteComment);
  }

  Future<void> _onLoadComments(LoadComments event, Emitter<CommentState> emit) async {
    try {
      emit(const CommentsLoading());
      final comments = await _commentRepository.getComments(event.documentId);
      emit(CommentsLoaded(comments));
    } catch (error) {
      LoggerUtil.error('Failed to load comments: $error');
      emit(CommentError('Failed to load comments: $error'));
    }
  }

  Future<void> _onLoadComment(LoadComment event, Emitter<CommentState> emit) async {
    try {
      emit(const CommentLoading());
      final comment = await _commentRepository.getComment(event.id);
      emit(CommentLoaded(comment));
    } catch (error) {
      LoggerUtil.error('Failed to load comment: $error');
      emit(CommentError('Failed to load comment: $error'));
    }
  }

  Future<void> _onCreateComment(CreateComment event, Emitter<CommentState> emit) async {
    try {
      emit(const CommentsLoading());
      final comment = await _commentRepository.createComment(
        event.documentId, 
        event.content,
        event.userId
      );
      emit(CommentCreated(comment));
      emit(const CommentOperationSuccess('Comment created successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to create comment: $error');
      emit(CommentError('Failed to create comment: $error'));
    }
  }

  Future<void> _onUpdateComment(UpdateComment event, Emitter<CommentState> emit) async {
    try {
      emit(const CommentsLoading());
      final result = await _commentRepository.updateComment(
        event.id,
        event.content
      );
      emit(CommentUpdated(result));
      emit(const CommentOperationSuccess('Comment updated successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to update comment: $error');
      emit(CommentError('Failed to update comment: $error'));
    }
  }

  Future<void> _onDeleteComment(DeleteComment event, Emitter<CommentState> emit) async {
    try {
      emit(const CommentsLoading());
      final result = await _commentRepository.deleteComment(event.id);
      emit(CommentDeleted(result));
      emit(const CommentOperationSuccess('Comment deleted successfully'));
    } catch (error) {
      LoggerUtil.error('Failed to delete comment: $error');
      emit(CommentError('Failed to delete comment: $error'));
    }
  }
} 
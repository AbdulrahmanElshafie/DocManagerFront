import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/models/comment.dart';
import 'package:doc_manager/blocs/comment/comment_bloc.dart';
import 'package:doc_manager/blocs/comment/comment_event.dart';
import 'package:doc_manager/blocs/comment/comment_state.dart';

class CommentsSection extends StatefulWidget {
  final String documentId;
  
  const CommentsSection({super.key, required this.documentId});

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // Load comments when the widget is initialized
    context.read<CommentBloc>().add(LoadComments(widget.documentId));
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocListener<CommentBloc, CommentState>(
      listener: (context, state) {
        if (state is CommentOperationSuccess) {
          // Reload comments after successful operation
          context.read<CommentBloc>().add(LoadComments(widget.documentId));
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is CommentError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: BlocBuilder<CommentBloc, CommentState>(
        builder: (context, state) {
          if (state is CommentsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is CommentError) {
            return Center(
              child: Column(
                children: [
                  Text('Error: ${state.error}'),
                  ElevatedButton(
                    onPressed: () => context.read<CommentBloc>().add(LoadComments(widget.documentId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (state is CommentsLoaded) {
            return _buildCommentsList(state.comments);
          }
          
          return _buildCommentsList([]);
        },
      ),
    );
  }
  
  Widget _buildCommentsList(List<Comment> comments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Comments (${comments.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Comment input field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                minLines: 1,
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    context.read<CommentBloc>().add(
                      CreateComment(
                        documentId: widget.documentId,
                        content: value,
                      ),
                    );
                    _commentController.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                if (_commentController.text.isNotEmpty) {
                  context.read<CommentBloc>().add(
                    CreateComment(
                      documentId: widget.documentId,
                      content: _commentController.text,
                    ),
                  );
                  _commentController.clear();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Comments list
        if (comments.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No comments yet',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final comment = comments[index];
              return ListTile(
                title: Text(comment.content),
                subtitle: Text(
                  '${comment.id} - ${comment.createdAt.toString().split('.')[0]}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    context.read<CommentBloc>().add(
                      DeleteComment(comment.id),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
} 
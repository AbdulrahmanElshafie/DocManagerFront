import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/comment.dart';

class CommentRepository {
  final ApiService _apiService = ApiService();

  Future<Comment> createComment(
      String documentId, String content, String userId) async {
    final response = await _apiService.post(API.comments, {
      'document_id': documentId,
      'content': content,
      'user_id': userId
    }, {});
    return Comment.fromJson(response);
  }

  Future<List<Comment>> getComments(String documentId) async {
    // final response = await _apiService.getList(API.comments, {'document_id': documentId});
    final response = await _apiService.get(API.comments, {'document_id': documentId});
    return (response as List).map((e) => Comment.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> deleteComment(String id) async {
    final response = await _apiService.delete(API.comments, id);
    return response;
  }

  Future<Map<String, dynamic>> updateComment(
      String id, String content) async {
    final response = await _apiService.put(API.comments, {
      'content': content
    }, id);
    return response;
  }

  Future<Comment> getComment(String id) async {
    final response = await _apiService.get(API.comments, {'id': id});
    return Comment.fromJson(response);
  }
}

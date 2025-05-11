import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/comment.dart';
import 'dart:developer' as developer;

class CommentRepository {
  final ApiService _apiService = ApiService();
  final bool _useMockData = true; // Temporary flag to use mock data

  // Mock data for comments
  final Map<String, List<Comment>> _mockComments = {};

  Future<Comment> createComment(
      String documentId, String content, String userId) async {
    if (_useMockData) {
      // Create a mock comment
      final comment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        documentId: documentId,
        content: content,
        userId: userId,
        userName: 'Current User', // Simple mock user name
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Add to mock storage
      if (!_mockComments.containsKey(documentId)) {
        _mockComments[documentId] = [];
      }
      _mockComments[documentId]!.add(comment);
      
      return comment;
    }
    
    try {
      final response = await _apiService.post(API.comments, {
        'document_id': documentId,
        'content': content,
        'user_id': userId
      }, {});
      return Comment.fromJson(response);
    } catch (e) {
      developer.log('Error creating comment: $e', name: 'CommentRepository');
      rethrow;
    }
  }

  Future<List<Comment>> getComments(String documentId) async {
    if (_useMockData) {
      return _mockComments[documentId] ?? [];
    }
    
    try {
      // Try using the getList method first with document_id as query param
      final response = await _apiService.getList(API.comments, {'document_id': documentId});
      return response.map((e) => Comment.fromJson(e)).toList();
    } catch (e) {
      developer.log('Error getting comments: $e', name: 'CommentRepository');
      return []; // Return empty list on error
    }
  }

  Future<Map<String, dynamic>> deleteComment(String id) async {
    if (_useMockData) {
      // Remove from all document lists
      _mockComments.forEach((key, value) {
        _mockComments[key] = value.where((comment) => comment.id != id).toList();
      });
      
      return {'success': true};
    }
    
    try {
      final response = await _apiService.delete(API.comments, id);
      return response;
    } catch (e) {
      developer.log('Error deleting comment: $e', name: 'CommentRepository');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateComment(
      String id, String content) async {
    if (_useMockData) {
      // Update in all document lists
      bool updated = false;
      _mockComments.forEach((key, value) {
        for (var i = 0; i < value.length; i++) {
          if (value[i].id == id) {
            _mockComments[key]![i] = value[i].copyWith(
              content: content,
              updatedAt: DateTime.now(),
            );
            updated = true;
            break;
          }
        }
      });
      
      return {'success': updated};
    }
    
    try {
      final response = await _apiService.put(API.comments, {
        'content': content
      }, id);
      return response;
    } catch (e) {
      developer.log('Error updating comment: $e', name: 'CommentRepository');
      return {'error': e.toString()};
    }
  }

  Future<Comment?> getComment(String id) async {
    if (_useMockData) {
      // Find in all document lists
      for (final comments in _mockComments.values) {
        for (final comment in comments) {
          if (comment.id == id) {
            return comment;
          }
        }
      }
      
      return null;
    }
    
    try {
      final response = await _apiService.get(API.comments, {'id': id});
      return Comment.fromJson(response);
    } catch (e) {
      developer.log('Error getting comment: $e', name: 'CommentRepository');
      return null;
    }
  }
}

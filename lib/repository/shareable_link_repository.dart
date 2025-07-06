import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/shareable_link.dart';

class ShareableLinkRepository {
  final ApiService _apiService = ApiService();

  Future<ShareableLink> createShareableLink(
      String? documentId, DateTime? expiresAt) async {
    final response = await _apiService.post('/manager/share/', {
      'document': documentId,
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': true
    }, {});
    return ShareableLink.fromJson(response);
  }

  Future<List<ShareableLink>> getShareableLinks() async {
    final response = await _apiService.getList('/manager/share/', {});
    return (response as List).map((e) => ShareableLink.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> deleteShareableLink(String id) async {
    final response = await _apiService.delete('/manager/share/', id);
    return response;
  }

  Future<Map<String, dynamic>> updateShareableLink(
      String id, String? documentId, DateTime? expiresAt, bool? isActive
      ) async {
    final response = await _apiService.put('/manager/share/', {
      'document': documentId,
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive
    }, id);
    return response;
  }

  Future<ShareableLink> getShareableLink(String token) async {
    final response = await _apiService.get('/manager/share/$token/', {});
    return ShareableLink.fromJson(response);
  }

}

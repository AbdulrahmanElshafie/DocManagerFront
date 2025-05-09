import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/user.dart';

class UserRepository {
  final ApiService _apiService = ApiService();

  Future<User> createUser(
      String firstName, String lastName, String email,
      String password, String password2, String username) async {
    final response = await _apiService.post(API.register, {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'password2': password2,
      'username': username
    }, {});
    return User.fromJson(response);
  }

  Future<Map<String, dynamic>> deleteUser(String id) async {
    final response = await _apiService.delete(API.userProfile, id);
    return response;
  }

  Future<Map<String, dynamic>> updateUser(
      String id, String parentId,  String name) async {
    final response = await _apiService.put(API.userProfile, {
      'parent': parentId,
      'name': name
    }, id);
    return response;
  }

  Future<User> getUser(String id) async {
    final response = await _apiService.get(API.userProfile, {'id': id});
    return User.fromJson(response);
  }

}

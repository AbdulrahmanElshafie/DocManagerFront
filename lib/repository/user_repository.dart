import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/user.dart';
import 'dart:developer' as developer;

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

  Future<User> getUser(String id) async {
    try {
      // According to the API docs, getting the user profile doesn't require an ID parameter
      // It uses the authenticated user's token to identify them
      final response = await _apiService.get(API.userProfile, {});
      developer.log('Got user profile: $response', name: 'UserRepository');
      return User.fromJson(response);
    } catch (e) {
      developer.log('Error getting user profile: $e', name: 'UserRepository');
      rethrow;
    }
  }
  
  Future<User> updateUser(User user) async {
    try {
      // According to API docs, we update the user by PUT/PATCH to /auth/user/ endpoint
      developer.log('Updating user with data: ${user.toJson()}', name: 'UserRepository');
      
      final response = await _apiService.put(API.userProfile, {
        'email': user.email,
        'first_name': user.firstName,
        'last_name': user.lastName
      }, '');
      
      developer.log('User update response: $response', name: 'UserRepository');
      return User.fromJson(response);
    } catch (e) {
      developer.log('Error updating user: $e', name: 'UserRepository');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resetPassword(
      String currentPassword, String newPassword, String confirmPassword) async {
    try {
      final response = await _apiService.post(API.passwordReset, {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password2': confirmPassword
      }, {});
      
      developer.log('Password reset response: $response', name: 'UserRepository');
      return response;
    } catch (e) {
      developer.log('Error resetting password: $e', name: 'UserRepository');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteUser(String id) async {
    try {
      final response = await _apiService.delete(API.userProfile, id);
      return response;
    } catch (e) {
      developer.log('Error deleting user: $e', name: 'UserRepository');
      rethrow;
    }
  }
}

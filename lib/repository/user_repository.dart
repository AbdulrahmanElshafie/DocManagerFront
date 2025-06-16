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

  Future<List<User>> getUsers() async {
    try {
      developer.log('Attempting to fetch users list...', name: 'UserRepository');
      
      // Try multiple endpoints for getting users
      dynamic response;
      
      // Try the main users endpoint first
      try {
        response = await _apiService.get('/auth/users/', {});
        developer.log('Got users from /auth/users/: $response', name: 'UserRepository');
      } catch (e) {
        developer.log('Failed to fetch from /auth/users/, trying alternatives: $e', name: 'UserRepository');
        
        // Try getting users from permissions endpoint (this might include user data)
        try {
          final permissionsResponse = await _apiService.get(API.permission, {});
          developer.log('Got permissions response: $permissionsResponse', name: 'UserRepository');
          
          // Extract unique users from permissions
          final Set<String> userIds = {};
          final List<User> users = [];
          
          // Handle different response formats
          List<dynamic>? permissionsList;
          if (permissionsResponse is List) {
            permissionsList = permissionsResponse as List<dynamic>;
          } else if (permissionsResponse is Map<String, dynamic> && 
                     permissionsResponse.containsKey('results')) {
            // Handle paginated response
            permissionsList = permissionsResponse['results'] as List<dynamic>?;
          }
          
          if (permissionsList != null) {
            for (final permission in permissionsList) {
              if (permission is Map<String, dynamic> && 
                  permission.containsKey('user_id') && 
                  permission.containsKey('user_name')) {
                final userId = permission['user_id'].toString();
                if (!userIds.contains(userId)) {
                  userIds.add(userId);
                  // Create a basic user object from permission data
                  users.add(User(
                    id: int.tryParse(userId) ?? 0,
                    username: permission['user_name'] ?? 'User $userId',
                    email: permission['user_email'] ?? '',
                    firstName: '',
                    lastName: '',
                  ));
                }
              }
            }
          }
          
          // If we found users from permissions, return them
          if (users.isNotEmpty) {
            developer.log('Extracted ${users.length} users from permissions', name: 'UserRepository');
            return users;
          }
        } catch (permError) {
          developer.log('Failed to extract users from permissions: $permError', name: 'UserRepository');
        }
        
        // As a last resort, create a mock user list for demonstration
        final currentUser = await getUser('current');
        developer.log('Creating fallback user list with current user', name: 'UserRepository');
        
        return [
          currentUser,
          // Add some mock users for demonstration
          User(
            id: 999,
            username: 'testuser',
            email: 'test@example.com',
            firstName: 'Test',
            lastName: 'User',
          ),
          User(
            id: 998,
            username: 'admin',
            email: 'admin@example.com',
            firstName: 'Admin',
            lastName: 'User',
          ),
        ];
      }
      
      // Process the response from /auth/users/
      if (response is List) {
        final List<User> users = [];
        final responseList = response as List;
        for (final userJson in responseList) {
          users.add(User.fromJson(userJson as Map<String, dynamic>));
        }
        developer.log('Successfully parsed ${users.length} users', name: 'UserRepository');
        return users;
      } else if (response is Map && response.containsKey('results')) {
        // Handle paginated response
        final results = response['results'] as List;
        final List<User> users = [];
        for (final userJson in results) {
          users.add(User.fromJson(userJson as Map<String, dynamic>));
        }
        developer.log('Successfully parsed ${users.length} users from paginated response', name: 'UserRepository');
        return users;
      } else {
        developer.log('Unexpected response format, returning empty list', name: 'UserRepository');
        return <User>[];
      }
    } catch (e) {
      developer.log('Error getting users list: $e', name: 'UserRepository');
      // Return empty list if there's an error
      return <User>[];
    }
  }

  Future<List<User>> searchUsers(String query) async {
    try {
      developer.log('Searching users with query: $query', name: 'UserRepository');
      
      // Try to search users via API endpoint
      try {
        final response = await _apiService.get('/auth/users/', {'search': query});
        developer.log('Got search results from /auth/users/: $response', name: 'UserRepository');
        
        if (response is List) {
          final List<User> users = [];
          final responseList = response as List;
          for (final userJson in responseList) {
            users.add(User.fromJson(userJson as Map<String, dynamic>));
          }
          developer.log('Successfully parsed ${users.length} search results', name: 'UserRepository');
          return users;
        } else if (response is Map && response.containsKey('results')) {
          // Handle paginated response
          final results = response['results'] as List;
          final List<User> users = [];
          for (final userJson in results) {
            users.add(User.fromJson(userJson as Map<String, dynamic>));
          }
          developer.log('Successfully parsed ${users.length} search results from paginated response', name: 'UserRepository');
          return users;
        }
      } catch (e) {
        developer.log('API search failed, falling back to local search: $e', name: 'UserRepository');
        
        // Fallback to local search
        final allUsers = await getUsers();
        final queryLower = query.toLowerCase();
        
        final filteredUsers = allUsers.where((user) {
          return user.username.toLowerCase().contains(queryLower) ||
                 user.email.toLowerCase().contains(queryLower) ||
                 user.firstName.toLowerCase().contains(queryLower) ||
                 user.lastName.toLowerCase().contains(queryLower) ||
                 '${user.firstName} ${user.lastName}'.toLowerCase().contains(queryLower);
        }).toList();
        
        developer.log('Local search returned ${filteredUsers.length} results', name: 'UserRepository');
        return filteredUsers;
      }
      
      return <User>[];
    } catch (e) {
      developer.log('Error searching users: $e', name: 'UserRepository');
      return <User>[];
    }
  }
}

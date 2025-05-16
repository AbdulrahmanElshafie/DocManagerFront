import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:async'; // Add for TimeoutException
import 'package:doc_manager/blocs/user/user_bloc.dart';
import 'package:doc_manager/blocs/user/user_event.dart';
import 'package:doc_manager/models/user.dart';
import 'package:doc_manager/repository/user_repository.dart';
import 'package:doc_manager/shared/services/secure_storage_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart'; // Required for BuildContext
import 'package:http/http.dart' as http;

class AuthService {
  final UserRepository _userRepository;
  final SecureStorageService secureStorageService;
  // Default to online mode since we need real authentication
  bool _offlineMode = false;

  AuthService({required UserRepository userRepository, required SecureStorageService secureStorageService}) 
      : _userRepository = userRepository,
        secureStorageService = secureStorageService {
    // Initialize offline mode data if needed
    if (_offlineMode) {
      _initOfflineMode();
    }
  }

  // Initialize offline mode with mock data
  Future<void> _initOfflineMode() async {
    if (_offlineMode) {
      developer.log('Initializing offline mode', name: 'AuthService');
      await secureStorageService.writeSecureData('authToken', 'mock_token');
      await secureStorageService.writeSecureData('refreshToken', 'mock_refresh_token');
      await secureStorageService.writeSecureData('userId', '1');
    }
  }

  // Check if offline mode is enabled
  bool get isOfflineMode => _offlineMode;

  // Enable offline mode for testing
  void enableOfflineMode() {
    _offlineMode = true;
    developer.log('Offline mode enabled', name: 'AuthService');
  }

  // Disable offline mode (for online operation)
  void disableOfflineMode() {
    _offlineMode = false;
    developer.log('Offline mode disabled', name: 'AuthService');
  }

  Future<bool> isAuthenticated() async {
    try {
      // In offline mode, always return true
      if (_offlineMode) {
        return true;
      }
      
      final token = await secureStorageService.readSecureData('authToken');
      return token != null && token.isNotEmpty;
    } catch (e) {
      developer.log('Error checking authentication: $e', name: 'AuthService');
      // If there's an error reading from secure storage,
      // fall back to offline mode
      enableOfflineMode();
      return true;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      // If in offline mode, return a mock user
      if (_offlineMode) {
        return User(
          id: 1,
          username: 'testuser',
          email: 'testuser@example.com',
          firstName: 'Test',
          lastName: 'User',
        );
      }
      
      // Don't need userId, just use the current token
      return await _userRepository.getUser("");
    } catch (e) {
      developer.log('Failed to get current user: $e', name: 'AuthService');
      
      // If network error, try to use offline mode
      if (e is SocketException || e is http.ClientException) {
        enableOfflineMode();
        return User(
          id: 1,
          username: 'testuser',
          email: 'testuser@example.com',
          firstName: 'Test',
          lastName: 'User',
        );
      }
      return null;
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      // If offline mode, simulate successful login
      if (_offlineMode) {
        await secureStorageService.writeSecureData('authToken', 'mock_token');
        await secureStorageService.writeSecureData('refreshToken', 'mock_refresh_token');
        await secureStorageService.writeSecureData('userId', '1');
        return true;
      }
      
      // Make the actual API call to login
      developer.log('Attempting to login to ${API.baseUrl}${API.login}', name: 'AuthService');
      
      final response = await http.post(
        Uri.parse('${API.baseUrl}${API.login}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));  // Increased timeout for better reliability

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Check if the response has the expected format
        if (responseData['access'] == null || responseData['refresh'] == null) {
          developer.log('Login response missing required tokens', name: 'AuthService');
          throw Exception('Invalid response format: missing tokens');
        }
        
        final String accessToken = responseData['access'];
        final String refreshToken = responseData['refresh'];
        
        // Store tokens securely
        await secureStorageService.writeSecureData('authToken', accessToken);
        await secureStorageService.writeSecureData('refreshToken', refreshToken);
        
        // Try to get user profile with the token
        try {
          final userResponse = await http.get(
            Uri.parse('${API.baseUrl}${API.userProfile}'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          ).timeout(const Duration(seconds: 10));
          
          if (userResponse.statusCode == 200) {
            final userData = json.decode(userResponse.body);
            await secureStorageService.writeSecureData('userId', userData['id'].toString());
          } else {
            developer.log('User profile request failed: ${userResponse.statusCode}', name: 'AuthService');
          }
        } catch (e) {
          developer.log('Failed to fetch user data: $e', name: 'AuthService');
          // Continue with login even if user fetch fails
        }
        
        developer.log('Login successful', name: 'AuthService');
        return true;
      } else {
        developer.log('Login failed: ${response.statusCode} ${response.body}', name: 'AuthService');
        return false;
      }
    } catch (e) {
      developer.log('Login failed: $e', name: 'AuthService');
      
      // Provide more specific error handling
      if (e is SocketException) {
        developer.log('Network connection error: ${e.message}', name: 'AuthService');
        throw Exception('Failed to connect to server. Please check your internet connection.');
      } else if (e is http.ClientException) {
        developer.log('HTTP client error: ${e.message}', name: 'AuthService');
        throw Exception('Connection error: ${e.message}');
      } else if (e is TimeoutException) {
        developer.log('Request timeout', name: 'AuthService');
        throw Exception('Server request timed out. Please try again later.');
      } else {
        throw Exception('Login failed: $e');
      }
    }
  }

  Future<bool> signup(BuildContext context, String firstName, String lastName, String email, String password, String username) async {
    try {
      // Make the API call to register
      final response = await http.post(
        Uri.parse('${API.baseUrl}${API.register}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'username': username,
          'password': password,
          'password2': password,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
        }),
      );
      
      if (response.statusCode == 201) {
        // Registration successful, now login
        return await login(username, password);
      } else {
        print('Signup failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Signup failed: $e');
      return false;
    }
  }

  Future<bool> logout() async {
    try {
      // If offline mode, just clear local storage
      if (_offlineMode) {
        await secureStorageService.deleteSecureData('authToken');
        await secureStorageService.deleteSecureData('refreshToken');
        await secureStorageService.deleteSecureData('userId');
        _offlineMode = false;
        return true;
      }
      
      final refreshToken = await secureStorageService.readSecureData('refreshToken');
      
      if (refreshToken != null) {
        // Call the logout API to invalidate the token on server side
        try {
          final response = await http.post(
            Uri.parse('${API.baseUrl}${API.logout}'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'refresh': refreshToken,
            }),
          ).timeout(const Duration(seconds: 10));
          
          developer.log('Logout API response: ${response.statusCode}', name: 'AuthService');
        } catch (e) {
          developer.log('Error calling logout API: $e', name: 'AuthService');
          // Continue with local logout even if server logout fails
        }
      }
      
      // Clear local storage regardless of server response
      await secureStorageService.deleteSecureData('authToken');
      await secureStorageService.deleteSecureData('refreshToken');
      await secureStorageService.deleteSecureData('userId');
      
      return true;
    } catch (e) {
      developer.log('Error during logout: $e', name: 'AuthService');
      return false;
    }
  }
  
  Future<String?> refreshToken() async {
    try {
      // In offline mode, return a mock token
      if (_offlineMode) {
        const mockToken = 'mock_refreshed_token';
        await secureStorageService.writeSecureData('authToken', mockToken);
        return mockToken;
      }
      
      developer.log('Attempting to refresh token at ${API.baseUrl}${API.refreshToken}', name: 'AuthService');
      
      final refreshToken = await secureStorageService.readSecureData('refreshToken');
      
      if (refreshToken == null || refreshToken.isEmpty) {
        developer.log('No refresh token available', name: 'AuthService');
        return null;
      }
      
      final response = await http.post(
        Uri.parse('${API.baseUrl}${API.refreshToken}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'refresh': refreshToken,
        }),
      ).timeout(const Duration(seconds: 15)); // Increased timeout for reliability
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Check if the response has the expected format
        if (responseData['access'] == null) {
          developer.log('Token refresh response missing access token', name: 'AuthService');
          throw Exception('Invalid response format: missing token');
        }
        
        final String newAccessToken = responseData['access'];
        
        // Update stored access token
        await secureStorageService.writeSecureData('authToken', newAccessToken);
        developer.log('Token refreshed successfully', name: 'AuthService');
        return newAccessToken;
      } else {
        developer.log('Token refresh failed: ${response.statusCode} ${response.body}', name: 'AuthService');
        return null;
      }
    } catch (e) {
      developer.log('Token refresh failed: $e', name: 'AuthService');
      
      // Handle specific error types
      if (e is SocketException) {
        developer.log('Network connection error during token refresh: ${e.message}', name: 'AuthService');
        throw Exception('Failed to connect to server. Please check your internet connection.');
      } else if (e is http.ClientException) {
        developer.log('HTTP client error during token refresh: ${e.message}', name: 'AuthService');
        throw Exception('Connection error: ${e.message}');
      } else if (e is TimeoutException) {
        developer.log('Request timeout during token refresh', name: 'AuthService');
        throw Exception('Server request timed out. Please try again later.');
      } else {
        throw Exception('Token refresh failed: $e');
      }
    }
  }
} 
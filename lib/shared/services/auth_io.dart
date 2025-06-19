import 'dart:io';
import 'package:http/http.dart' as http;

// Helper method to check if an exception is a network error on mobile/desktop platforms
bool isNetworkError(dynamic error) {
  return error is SocketException || 
         error is http.ClientException || 
         error is HttpException ||
         error.toString().contains('Connection') ||
         error.toString().contains('timeout');
} 
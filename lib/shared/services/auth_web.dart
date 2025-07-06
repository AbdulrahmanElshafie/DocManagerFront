import 'package:http/http.dart' as http;

// Helper method to check if an exception is a network error on web platforms
bool isNetworkError(dynamic error) {
  // On web, we can't check for specific exception types like SocketException, 
  // so check error message and types that are available
  return error is http.ClientException || 
         error.toString().contains('Network') ||
         error.toString().contains('CORS') ||
         error.toString().contains('timeout');
} 
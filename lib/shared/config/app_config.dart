class AppConfig {
  static const String _defaultBaseUrl = 'http://localhost:8000/api';
  
  static String get baseUrl {
    // Check for environment variable first
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    
    // Check for build-time configuration
    return _getConfiguredBaseUrl();
  }
  
  static String _getConfiguredBaseUrl() {
    // You can add different URLs for different build modes
    const bool kDebugMode = true; // This should come from Flutter
    
    if (kDebugMode) {
      return 'http://localhost:8000/api';
    } else {
      return 'https://your-production-api.com/api';
    }
  }
  
  static bool get isProduction => !baseUrl.contains('localhost');
  
  // Timeout configuration
  static const Duration defaultTimeout = Duration(seconds: 30);
  
  // File upload configuration
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
} 
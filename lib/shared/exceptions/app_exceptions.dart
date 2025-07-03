class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  AppException(this.message, {this.code, this.originalError});
  
  @override
  String toString() => 'AppException: $message';
}

class NetworkException extends AppException {
  final int? statusCode;
  
  NetworkException(String message, {this.statusCode, String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

class FileException extends AppException {
  FileException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
}

class ValidationException extends AppException {
  ValidationException(String message, {String? code, dynamic originalError})
      : super(message, code: code, originalError: originalError);
} 
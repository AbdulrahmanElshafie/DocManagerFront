class ValidationResult {
  final bool isValid;
  final List<String> errors;
  
  ValidationResult({required this.isValid, required this.errors});
  
  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, errors: $errors)';
  }
} 
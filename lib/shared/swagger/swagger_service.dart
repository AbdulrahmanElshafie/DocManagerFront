import 'dart:convert';
import 'package:http/http.dart' as http;

class SwaggerService {
  static final SwaggerService _instance = SwaggerService._internal();
  final String _swaggerDocsUrl = '/api/docs/';

  // Private constructor
  SwaggerService._internal();

  // Singleton instance
  factory SwaggerService() {
    return _instance;
  }

  /// Generate Swagger documentation for the API
  Future<Map<String, dynamic>> generateApiDocs() async {
    try {
      final response = await http.get(Uri.parse(_swaggerDocsUrl));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to generate API documentation');
      }
    } catch (e) {
      throw Exception('Error generating API documentation: $e');
    }
  }
  
  /// Model documentation generator function
  Map<String, dynamic> generateModelDocs(String modelName, Map<String, dynamic> modelSchema) {
    return {
      'name': modelName,
      'properties': modelSchema,
      'required': modelSchema.keys.toList(),
    };
  }
  
  /// API endpoint documentation generator function
  Map<String, dynamic> generateEndpointDocs(
    String endpointPath, 
    String method, 
    Map<String, dynamic> requestBody,
    Map<String, dynamic> responseSchema,
    List<String> tags,
  ) {
    return {
      'path': endpointPath,
      'method': method,
      'requestBody': {
        'required': true,
        'content': {
          'application/json': {
            'schema': requestBody
          }
        }
      },
      'responses': {
        '200': {
          'description': 'Successful operation',
          'content': {
            'application/json': {
              'schema': responseSchema
            }
          }
        },
        '400': {
          'description': 'Bad request'
        },
        '401': {
          'description': 'Unauthorized'
        },
        '500': {
          'description': 'Server error'
        }
      },
      'tags': tags,
    };
  }
} 
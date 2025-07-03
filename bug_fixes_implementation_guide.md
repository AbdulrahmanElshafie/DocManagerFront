# Bug Fixes Implementation Guide

This document provides detailed step-by-step instructions for fixing each identified bug in the Document Manager Flutter app.

## CRITICAL BUGS (Fix Immediately)

### Bug #1: File Path Handling Issues in Document Model
**File:** `lib/models/document.dart` (lines 50-95)

#### Implementation Steps:
1. **Create a platform-aware file path validator**
   ```dart
   static bool _isValidFilePath(String? path) {
     if (path == null || path.isEmpty || path.trim() == 'path') {
       return false;
     }
     
     if (kIsWeb) {
       // For web, accept URLs and basic validation
       return path.startsWith('http') || path.startsWith('blob:') || path.length > 0;
     } else {
       // For mobile/desktop, validate actual file paths
       try {
         final normalizedPath = path.replaceAll('\\', '/');
         return normalizedPath.isNotEmpty && !normalizedPath.contains('//');
       } catch (e) {
         return false;
       }
     }
   }
   ```

2. **Simplify the fromJson file handling logic**
   ```dart
   // Replace the complex nested try-catch blocks (lines 50-95) with:
   factory Document.fromJson(Map<String, dynamic> json) {
     developer.log('Parsing document JSON: $json', name: 'Document.fromJson');
     
     io.File? fileObj;
     String? filePathStr;
     
     // Extract file path from JSON
     if (json['file'] != null) {
       filePathStr = json['file'] is String ? json['file'] : null;
       
       // Validate file path
       if (_isValidFilePath(filePathStr)) {
         // Normalize path for non-web platforms
         if (!kIsWeb && filePathStr != null) {
           filePathStr = filePathStr.replaceAll('\\', '/');
           try {
             fileObj = io.File(filePathStr);
           } catch (e) {
             developer.log('Could not create File object: $e', name: 'Document.fromJson');
             fileObj = null;
           }
         }
       } else {
         developer.log('Invalid file path: $filePathStr', name: 'Document.fromJson');
         filePathStr = null;
       }
     }
     
     // Rest of the method remains the same...
   }
   ```

3. **Add file validation method**
   ```dart
   bool hasValidFile() {
     if (kIsWeb) {
       return fileUrl != null && fileUrl!.isNotEmpty;
     } else {
       return file != null && FileUtils.existsSync(file!);
     }
   }
   ```

#### Acceptance Criteria:
- ✅ No nested try-catch blocks in fromJson
- ✅ Platform-specific file path validation
- ✅ Proper error logging without exceptions
- ✅ Valid file objects only created when appropriate

---

### Bug #2: Platform-Specific File Handling Not Properly Abstracted
**File:** `lib/shared/utils/file_utils.dart`

#### Implementation Steps:
1. **Replace hardcoded web returns with proper abstractions**
   ```dart
   // Replace existing FileUtils class with:
   class FileUtils {
     static String getFileName(dynamic file) {
       if (kIsWeb) {
         // For web, try to extract filename from File object properties
         try {
           return file.name ?? 'web_file';
         } catch (e) {
           return 'web_file';
         }
       } else {
         try {
           return path.basename(file.path);
         } catch (e) {
           return 'unknown_file';
         }
       }
     }
     
     static Future<bool> fileExists(dynamic file) async {
       if (kIsWeb) {
         // For web, check if file object is valid
         try {
           return file != null && file.size != null;
         } catch (e) {
           return false;
         }
       } else {
         try {
           return await file.exists();
         } catch (e) {
           return false;
         }
       }
     }
     
     static bool existsSync(dynamic file) {
       if (kIsWeb) {
         try {
           return file != null && file.size != null;
         } catch (e) {
           return false;
         }
       } else {
         try {
           return file.existsSync();
         } catch (e) {
           return false;
         }
       }
     }
     
     static Future<int> getFileSize(dynamic file) async {
       if (kIsWeb) {
         try {
           return file.size ?? 0;
         } catch (e) {
           return 0;
         }
       } else {
         try {
           return await file.length();
         } catch (e) {
           return 0;
         }
       }
     }
   }
   ```

2. **Add web-specific file handling class**
   ```dart
   // Create new file: lib/shared/utils/web_file_utils.dart
   import 'dart:html' as html;
   
   class WebFileUtils {
     static Future<List<int>> readFileAsBytes(html.File file) async {
       final reader = html.FileReader();
       reader.readAsArrayBuffer(file);
       await reader.onLoad.first;
       return reader.result as List<int>;
     }
     
     static Future<String> readFileAsString(html.File file) async {
       final reader = html.FileReader();
       reader.readAsText(file);
       await reader.onLoad.first;
       return reader.result as String;
     }
   }
   ```

#### Acceptance Criteria:
- ✅ Web file operations return actual file properties
- ✅ Proper error handling for both platforms
- ✅ No hardcoded return values
- ✅ Web-specific utilities for file reading

---

### Bug #3: Resource Leaks in DocumentRepository
**File:** `lib/repository/document_repository.dart`

#### Implementation Steps:
1. **Create a temporary file manager class**
   ```dart
   // Create new file: lib/shared/utils/temp_file_manager.dart
   import 'dart:io';
   import 'package:path_provider/path_provider.dart';
   
   class TempFileManager {
     static final Set<String> _createdFiles = <String>{};
     
     static Future<File> createTempFile(String fileName) async {
       final tempDir = await getTemporaryDirectory();
       final tempFile = File('${tempDir.path}/$fileName');
       _createdFiles.add(tempFile.path);
       return tempFile;
     }
     
     static Future<void> cleanup() async {
       for (String filePath in _createdFiles) {
         try {
           final file = File(filePath);
           if (await file.exists()) {
             await file.delete();
           }
         } catch (e) {
           developer.log('Failed to cleanup temp file: $filePath, error: $e');
         }
       }
       _createdFiles.clear();
     }
     
     static Future<void> cleanupFile(String filePath) async {
       try {
         final file = File(filePath);
         if (await file.exists()) {
           await file.delete();
         }
         _createdFiles.remove(filePath);
       } catch (e) {
         developer.log('Failed to cleanup specific temp file: $filePath, error: $e');
       }
     }
   }
   ```

2. **Update DocumentRepository methods to use TempFileManager**
   ```dart
   // In createDocument method (around lines 108-130):
   Future<Document> createDocument(String folderId, io.File file, String name) async {
     io.File? tempFile;
     try {
       // ... existing validation code ...
       
       if (!kIsWeb) {
         final fileName = FileUtils.getFileName(file);
         tempFile = await TempFileManager.createTempFile(fileName);
         await FileUtils.copyFile(file, FileUtils.getFilePath(tempFile)!);
         
         final response = await _apiService.uploadFile(API.document, tempFile, {
           'folder': folderId,
           'name': name,
         });
         
         return Document.fromJson(response);
       }
       // ... rest of method
     } catch (e) {
       developer.log('Error creating document: $e', name: 'DocumentRepository');
       rethrow;
     } finally {
       // Cleanup temp file
       if (tempFile != null) {
         await TempFileManager.cleanupFile(FileUtils.getFilePath(tempFile)!);
       }
     }
   }
   ```

3. **Add cleanup to all repository methods**
   - Update `createContentDocument` method
   - Update `updateDocument` method
   - Add cleanup to constructor/dispose pattern

4. **Add app-level cleanup**
   ```dart
   // In main.dart, add cleanup when app terminates:
   class MyApp extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       return MaterialApp(
         // ... existing config
         home: AppLifecycleObserver(child: const MainScreen()),
       );
     }
   }
   
   class AppLifecycleObserver extends StatefulWidget {
     final Widget child;
     const AppLifecycleObserver({required this.child, super.key});
     
     @override
     State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
   }
   
   class _AppLifecycleObserverState extends State<AppLifecycleObserver> with WidgetsBindingObserver {
     @override
     void initState() {
       super.initState();
       WidgetsBinding.instance.addObserver(this);
     }
     
     @override
     void dispose() {
       WidgetsBinding.instance.removeObserver(this);
       TempFileManager.cleanup();
       super.dispose();
     }
     
     @override
     void didChangeAppLifecycleState(AppLifecycleState state) {
       if (state == AppLifecycleState.detached) {
         TempFileManager.cleanup();
       }
     }
     
     @override
     Widget build(BuildContext context) => widget.child;
   }
   ```

#### Acceptance Criteria:
- ✅ All temporary files tracked and cleaned up
- ✅ Cleanup on app termination
- ✅ Individual file cleanup after operations
- ✅ Error handling in cleanup operations

---

### Bug #4: Inconsistent Error Handling in API Service
**File:** `lib/shared/network/api_service.dart`

#### Implementation Steps:
1. **Create standardized logging utility**
   ```dart
   // Create new file: lib/shared/utils/app_logger.dart
   import 'dart:developer' as developer;
   
   enum LogLevel { debug, info, warning, error }
   
   class AppLogger {
     static void log(String message, {
       LogLevel level = LogLevel.info,
       String? name,
       Object? error,
       StackTrace? stackTrace,
     }) {
       developer.log(
         message,
         level: _getLevelValue(level),
         name: name ?? 'App',
         error: error,
         stackTrace: stackTrace,
       );
     }
     
     static int _getLevelValue(LogLevel level) {
       switch (level) {
         case LogLevel.debug: return 500;
         case LogLevel.info: return 800;
         case LogLevel.warning: return 900;
         case LogLevel.error: return 1000;
       }
     }
     
     static void debug(String message, {String? name}) =>
         log(message, level: LogLevel.debug, name: name);
     
     static void info(String message, {String? name}) =>
         log(message, level: LogLevel.info, name: name);
     
     static void warning(String message, {String? name}) =>
         log(message, level: LogLevel.warning, name: name);
     
     static void error(String message, {String? name, Object? error, StackTrace? stackTrace}) =>
         log(message, level: LogLevel.error, name: name, error: error, stackTrace: stackTrace);
   }
   ```

2. **Replace all print() statements with AppLogger**
   ```dart
   // Replace all instances of:
   print('GET REQUEST: $url');
   // With:
   AppLogger.debug('GET REQUEST: $url', name: 'ApiService');
   
   // Replace all instances of:
   print('ERROR parsing JSON list: $e');
   // With:
   AppLogger.error('ERROR parsing JSON list', name: 'ApiService', error: e);
   ```

3. **Create custom exception classes**
   ```dart
   // Create new file: lib/shared/exceptions/app_exceptions.dart
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
   ```

4. **Update error handling in API methods**
   ```dart
   // Replace generic Exception throws with specific exceptions:
   Future<Map<String, dynamic>> get(String endpoint, Map<String, dynamic> kwargs) async {
     try {
       String url = buildUrl(endpoint, kwargs);
       final headers = await _getHeaders();
       
       AppLogger.debug('GET REQUEST: $url', name: 'ApiService');
       
       final response = await http.get(Uri.parse(url), headers: headers);
       
       AppLogger.debug('GET RESPONSE (${response.statusCode}): ${response.body}', name: 'ApiService');

       if (response.statusCode == 200) {
         try {
           return json.decode(response.body);
         } catch (e) {
           throw NetworkException('Failed to parse response JSON', 
             statusCode: response.statusCode, originalError: e);
         }
       } else {
         throw NetworkException('Request failed', 
           statusCode: response.statusCode, code: 'HTTP_${response.statusCode}');
       }
     } catch (e) {
       if (e is NetworkException) rethrow;
       AppLogger.error('GET request failed', name: 'ApiService', error: e);
       throw NetworkException('Network request failed', originalError: e);
     }
   }
   ```

5. **Remove fallback logic that creates placeholder content**
   ```dart
   // In uploadFile method, remove lines 270-290 fallback logic
   // Instead, let the exception propagate properly:
   } catch (e) {
     AppLogger.error('UPLOAD EXCEPTION', name: 'ApiService', error: e);
     throw FileException('Failed to upload file: ${filename}', originalError: e);
   }
   ```

#### Acceptance Criteria:
- ✅ Consistent logging using AppLogger throughout
- ✅ Specific exception types for different error scenarios
- ✅ No silent failures or placeholder content creation
- ✅ Proper error propagation to UI layer

---

## HIGH PRIORITY BUGS

### Bug #5: Missing Data Validation in Models
**File:** `lib/models/document.dart`

#### Implementation Steps:
1. **Add validation methods to Document class**
   ```dart
   class Document extends Equatable {
     // ... existing fields ...
     
     // Add validation methods
     static ValidationResult validateDocument(Map<String, dynamic> json) {
       final errors = <String>[];
       
       if (json['id'] == null || json['id'].toString().isEmpty) {
         errors.add('Document ID is required');
       }
       
       if (json['name'] == null || json['name'].toString().trim().isEmpty) {
         errors.add('Document name is required');
       }
       
       if (json['owner'] == null || json['owner'].toString().isEmpty) {
         errors.add('Document owner is required');
       }
       
       if (json['folder'] == null || json['folder'].toString().isEmpty) {
         errors.add('Document folder is required');
       }
       
       if (json['created_at'] == null) {
         errors.add('Document creation date is required');
       } else {
         try {
           DateTime.parse(json['created_at']);
         } catch (e) {
           errors.add('Invalid creation date format');
         }
       }
       
       return ValidationResult(isValid: errors.isEmpty, errors: errors);
     }
     
     bool get isValid {
       return id.isNotEmpty && 
              name.trim().isNotEmpty && 
              ownerId.isNotEmpty && 
              folderId.isNotEmpty;
     }
   }
   
   // Create validation result class
   class ValidationResult {
     final bool isValid;
     final List<String> errors;
     
     ValidationResult({required this.isValid, required this.errors});
   }
   ```

2. **Update fromJson to use validation**
   ```dart
   factory Document.fromJson(Map<String, dynamic> json) {
     developer.log('Parsing document JSON: $json', name: 'Document.fromJson');
     
     // Validate input data
     final validation = Document.validateDocument(json);
     if (!validation.isValid) {
       AppLogger.warning('Document validation failed: ${validation.errors}', name: 'Document.fromJson');
       // Continue with defaults but log the issues
     }
     
     // ... rest of fromJson method with proper null handling
     return Document(
       id: json['id']?.toString() ?? '',
       name: json['name']?.toString().trim() ?? 'Unnamed Document',
       // ... other fields with proper null handling
     );
   }
   ```

3. **Add similar validation to other models**
   - Update `User`, `Folder`, `Comment`, etc. models
   - Create base validation interface

#### Acceptance Criteria:
- ✅ All required fields validated
- ✅ Proper error messages for validation failures
- ✅ Graceful handling of invalid data
- ✅ Consistent validation across all models

---

### Bug #6: Hardcoded Base URLs
**File:** `lib/shared/network/api.dart`

#### Implementation Steps:
1. **Create environment configuration**
   ```dart
   // Create new file: lib/shared/config/app_config.dart
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
   }
   ```

2. **Create environment-specific configuration files**
   ```yaml
   # Create file: configs/development.yaml
   api:
     base_url: "http://localhost:8000/api"
     timeout: 30000
   
   # Create file: configs/staging.yaml
   api:
     base_url: "https://staging-api.yourdomain.com/api"
     timeout: 60000
   
   # Create file: configs/production.yaml
   api:
     base_url: "https://api.yourdomain.com/api"
     timeout: 60000
   ```

3. **Update API class to use configuration**
   ```dart
   // Update lib/shared/network/api.dart:
   import '../config/app_config.dart';
   
   class API {
     static String get baseUrl => AppConfig.baseUrl;
     
     // ... rest of the endpoints remain the same
   }
   ```

4. **Add configuration loading**
   ```dart
   // Add to pubspec.yaml:
   # dependencies:
   #   yaml: ^3.1.2
   
   // Create lib/shared/config/config_loader.dart:
   import 'dart:convert';
   import 'package:flutter/services.dart';
   import 'package:yaml/yaml.dart';
   
   class ConfigLoader {
     static Map<String, dynamic>? _config;
     
     static Future<void> loadConfig() async {
       try {
         const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
         final configString = await rootBundle.loadString('configs/$environment.yaml');
         final yaml = loadYaml(configString);
         _config = Map<String, dynamic>.from(yaml);
       } catch (e) {
         AppLogger.error('Failed to load configuration', error: e);
         _config = <String, dynamic>{};
       }
     }
     
     static String getString(String key, {String defaultValue = ''}) {
       return _config?[key]?.toString() ?? defaultValue;
     }
     
     static int getInt(String key, {int defaultValue = 0}) {
       return _config?[key] ?? defaultValue;
     }
   }
   ```

5. **Update main.dart to load configuration**
   ```dart
   // In main.dart:
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await ConfigLoader.loadConfig();
     runApp(const MyApp());
   }
   ```

#### Acceptance Criteria:
- ✅ No hardcoded URLs in code
- ✅ Environment-specific configuration
- ✅ Easy deployment to different environments
- ✅ Runtime configuration loading

---

### Bug #7: Multiple State Emissions in DocumentBloc
**File:** `lib/blocs/document/document_bloc.dart`

#### Implementation Steps:
1. **Refactor event handlers to emit single final state**
   ```dart
   Future<void> _onCreateDocument(CreateDocument event, Emitter<DocumentState> emit) async {
     try {
       emit(const DocumentsLoading());
       
       // Perform all operations
       final document = await _documentRepository.createContentDocument(
         event.folderId,
         event.name,
         event.content ?? ''
       );
       
       final documents = await _documentRepository.getDocuments(
         folderId: event.folderId
       );
       
       // Emit single combined state
       emit(DocumentCreatedWithList(document: document, documents: documents));
       
     } catch (error) {
       AppLogger.error('Failed to create document', name: 'DocumentBloc', error: error);
       emit(DocumentError('Failed to create document: $error'));
     }
   }
   ```

2. **Create new combined state classes**
   ```dart
   // Add to lib/blocs/document/document_state.dart:
   class DocumentCreatedWithList extends DocumentState {
     final Document document;
     final List<Document> documents;
     
     const DocumentCreatedWithList({
       required this.document,
       required this.documents,
     });
     
     @override
     List<Object> get props => [document, documents];
   }
   
   class DocumentUpdatedWithList extends DocumentState {
     final Map<String, dynamic> updateResult;
     final Document document;
     final List<Document>? documents;
     
     const DocumentUpdatedWithList({
       required this.updateResult,
       required this.document,
       this.documents,
     });
     
     @override
     List<Object?> get props => [updateResult, document, documents];
   }
   
   class DocumentDeletedWithList extends DocumentState {
     final Map<String, dynamic> deleteResult;
     final List<Document>? documents;
     
     const DocumentDeletedWithList({
       required this.deleteResult,
       this.documents,
     });
     
     @override
     List<Object?> get props => [deleteResult, documents];
   }
   ```

3. **Add operation success indicators within states**
   ```dart
   // Instead of separate DocumentOperationSuccess state, add success flag to existing states:
   class DocumentsLoaded extends DocumentState {
     final List<Document> documents;
     final String? successMessage;
     
     const DocumentsLoaded(this.documents, {this.successMessage});
     
     @override
     List<Object?> get props => [documents, successMessage];
   }
   ```

4. **Update UI to handle combined states**
   ```dart
   // Update widgets that listen to DocumentBloc:
   BlocListener<DocumentBloc, DocumentState>(
     listener: (context, state) {
       if (state is DocumentCreatedWithList) {
         // Show success message
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Document created successfully')),
         );
         // Update UI with new document and list
       } else if (state is DocumentError) {
         // Handle error
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(state.message)),
         );
       }
     },
     child: BlocBuilder<DocumentBloc, DocumentState>(
       builder: (context, state) {
         if (state is DocumentsLoading) {
           return const CircularProgressIndicator();
         } else if (state is DocumentCreatedWithList) {
           return DocumentList(documents: state.documents);
         } else if (state is DocumentsLoaded) {
           return DocumentList(documents: state.documents);
         }
         // ... other state handlers
       },
     ),
   )
   ```

#### Acceptance Criteria:
- ✅ Single state emission per operation
- ✅ Combined states with all necessary data
- ✅ No UI flicker from rapid state changes
- ✅ Clear success/error handling

---

### Bug #8: Nullable Parameter Handling
**File:** `lib/blocs/document/document_bloc.dart`

#### Implementation Steps:
1. **Create proper parameter validation**
   ```dart
   Future<void> _onUpdateDocument(UpdateDocument event, Emitter<DocumentState> emit) async {
     try {
       emit(const DocumentsLoading());
       
       // Validate required parameters
       if (event.id.isEmpty) {
         emit(const DocumentError('Document ID is required for update'));
         return;
       }
       
       if (event.name?.trim().isEmpty ?? true) {
         emit(const DocumentError('Document name cannot be empty'));
         return;
       }
       
       // Use null values instead of empty strings
       final result = await _documentRepository.updateDocument(
         event.id,
         event.folderId?.isNotEmpty == true ? event.folderId! : null,
         event.file,
         event.name!.trim(),
         content: event.content?.isNotEmpty == true ? event.content : null,
       );
       
       // Rest of method...
     } catch (error) {
       AppLogger.error('Failed to update document', name: 'DocumentBloc', error: error);
       emit(DocumentError('Failed to update document: $error'));
     }
   }
   ```

2. **Update repository to handle null values properly**
   ```dart
   // In DocumentRepository.updateDocument:
   Future<Map<String, dynamic>> updateDocument(
       String id, 
       String? folderId, 
       io.File? file, 
       String name, 
       {String? content}) async {
     try {
       // Validate required parameters
       if (id.isEmpty) {
         throw ValidationException('Document ID is required');
       }
       
       if (name.trim().isEmpty) {
         throw ValidationException('Document name cannot be empty');
       }
       
       // Build update data with only non-null values
       final updateData = <String, dynamic>{
         'name': name.trim(),
       };
       
       if (folderId != null) {
         updateData['folder'] = folderId;
       }
       
       // Rest of method...
     } catch (e) {
       AppLogger.error('Error updating document', name: 'DocumentRepository', error: e);
       rethrow;
     }
   }
   ```

3. **Update event classes to be more explicit about nullable fields**
   ```dart
   // In lib/blocs/document/document_event.dart:
   class UpdateDocument extends DocumentEvent {
     final String id;
     final String? folderId;  // null means don't update folder
     final io.File? file;     // null means don't update file
     final String? name;      // null means don't update name, but should validate if provided
     final String? content;   // null means don't update content
     
     const UpdateDocument({
       required this.id,
       this.folderId,
       this.file,
       this.name,
       this.content,
     });
     
     @override
     List<Object?> get props => [id, folderId, file, name, content];
   }
   ```

#### Acceptance Criteria:
- ✅ No empty string fallbacks for nullable parameters
- ✅ Proper null handling in repository layer
- ✅ Clear validation error messages
- ✅ Explicit nullable field handling

---

## MEDIUM PRIORITY BUGS

### Bug #9: File Viewer Platform Compatibility
**File:** `lib/widgets/unified_document_viewer.dart`

#### Implementation Steps:
1. **Create platform-specific document viewer factory**
   ```dart
   // Create new file: lib/widgets/platform_document_viewer.dart
   import 'package:flutter/foundation.dart';
   import 'package:flutter/material.dart';
   import '../models/document.dart';
   
   abstract class PlatformDocumentViewer {
     static Widget create(Document document) {
       if (kIsWeb) {
         return WebDocumentViewer(document: document);
       } else {
         return MobileDocumentViewer(document: document);
       }
     }
   }
   
   class WebDocumentViewer extends StatelessWidget {
     final Document document;
     
     const WebDocumentViewer({required this.document, super.key});
     
     @override
     Widget build(BuildContext context) {
       final fileUrl = document.getAbsoluteFileUrl();
       
       if (fileUrl == null) {
         return _buildErrorView(context, 'No file URL available');
       }
       
       // For web, use iframe or direct URL opening
       return Container(
         width: double.infinity,
         height: double.infinity,
         child: _buildWebViewer(fileUrl, document.type),
       );
     }
     
     Widget _buildWebViewer(String url, DocumentType type) {
       switch (type) {
         case DocumentType.pdf:
           return _buildPdfWebViewer(url);
         case DocumentType.csv:
           return _buildCsvWebViewer(url);
         case DocumentType.docx:
           return _buildDocxWebViewer(url);
         default:
           return _buildUnsupportedWebView();
       }
     }
     
     Widget _buildPdfWebViewer(String url) {
       // Use PDF.js or similar web PDF viewer
       return HtmlElementView(
         viewType: 'pdf-viewer',
         creationParams: {'url': url},
       );
     }
     
     // Additional web viewer methods...
   }
   
   class MobileDocumentViewer extends StatelessWidget {
     final Document document;
     
     const MobileDocumentViewer({required this.document, super.key});
     
     @override
     Widget build(BuildContext context) {
       // Use platform-appropriate viewer
       if (document.file != null && FileUtils.existsSync(document.file!)) {
         return UniversalFileViewer(file: document.file!);
       } else if (document.getAbsoluteFileUrl() != null) {
         return NetworkFileViewer(url: document.getAbsoluteFileUrl()!);
       } else {
         return _buildErrorView(context, 'File not available');
       }
     }
   }
   ```

2. **Create network file viewer for mobile**
   ```dart
   // Add to mobile document viewer:
   class NetworkFileViewer extends StatefulWidget {
     final String url;
     
     const NetworkFileViewer({required this.url, super.key});
     
     @override
     State<NetworkFileViewer> createState() => _NetworkFileViewerState();
   }
   
   class _NetworkFileViewerState extends State<NetworkFileViewer> {
     File? _localFile;
     bool _isLoading = true;
     String? _error;
     
     @override
     void initState() {
       super.initState();
       _downloadAndViewFile();
     }
     
     Future<void> _downloadAndViewFile() async {
       try {
         final response = await http.get(Uri.parse(widget.url));
         if (response.statusCode == 200) {
           final tempFile = await TempFileManager.createTempFile(
             'downloaded_${DateTime.now().millisecondsSinceEpoch}.pdf'
           );
           await tempFile.writeAsBytes(response.bodyBytes);
           
           if (mounted) {
             setState(() {
               _localFile = tempFile;
               _isLoading = false;
             });
           }
         } else {
           throw Exception('Failed to download file: ${response.statusCode}');
         }
       } catch (e) {
         if (mounted) {
           setState(() {
             _error = e.toString();
             _isLoading = false;
           });
         }
       }
     }
     
     @override
     Widget build(BuildContext context) {
       if (_isLoading) {
         return const Center(child: CircularProgressIndicator());
       } else if (_error != null) {
         return Center(child: Text('Error: $_error'));
       } else if (_localFile != null) {
         return UniversalFileViewer(file: _localFile!);
       } else {
         return const Center(child: Text('Unable to load file'));
       }
     }
   }
   ```

3. **Update unified document viewer to use platform factory**
   ```dart
   // In lib/widgets/unified_document_viewer.dart, replace _buildDocumentViewer:
   Widget _buildDocumentViewer() {
     return PlatformDocumentViewer.create(widget.document);
   }
   ```

#### Acceptance Criteria:
- ✅ Web platform uses appropriate web viewers
- ✅ Mobile platform handles both local and remote files
- ✅ Proper error handling for each platform
- ✅ No platform-specific crashes

---

### Bug #10: Unimplemented Features with TODO
**File:** `lib/widgets/unified_document_viewer.dart`

#### Implementation Steps:
1. **Implement document sharing functionality**
   ```dart
   // Replace the TODO implementation in _shareDocument method:
   void _shareDocument() async {
     try {
       final fileUrl = widget.document.getAbsoluteFileUrl();
       
       if (fileUrl != null) {
         // Use share_plus package for sharing
         await Share.share(
           fileUrl,
           subject: 'Shared document: ${widget.document.name}',
         );
       } else {
         // Share document metadata if no file URL
         await Share.share(
           'Document: ${widget.document.name}\n'
           'Type: ${_getDocumentTypeString(widget.document.type)}\n'
           'Created: ${_formatDate(widget.document.createdAt)}',
           subject: 'Document Information',
         );
       }
     } catch (e) {
       AppLogger.error('Failed to share document', error: e);
       _showErrorSnackBar('Failed to share document: $e');
     }
   }
   ```

2. **Add share link generation for web**
   ```dart
   // Create new file: lib/shared/services/share_service.dart
   class ShareService {
     static Future<String> generateShareLink(Document document) async {
       try {
         final response = await ApiService().post('/manager/share/', {
           'document_id': document.id,
           'expires_in': 24 * 60 * 60, // 24 hours in seconds
         }, {});
         
         return response['share_url'] ?? '';
       } catch (e) {
         AppLogger.error('Failed to generate share link', error: e);
         rethrow;
       }
     }
     
     static Future<void> copyToClipboard(String text) async {
       await Clipboard.setData(ClipboardData(text: text));
     }
   }
   ```

3. **Update share dialog for better UX**
   ```dart
   void _shareDocument() async {
     showDialog(
       context: context,
       builder: (context) => ShareDialog(document: widget.document),
     );
   }
   
   // Create new widget: ShareDialog
   class ShareDialog extends StatefulWidget {
     final Document document;
     
     const ShareDialog({required this.document, super.key});
     
     @override
     State<ShareDialog> createState() => _ShareDialogState();
   }
   
   class _ShareDialogState extends State<ShareDialog> {
     String? _shareLink;
     bool _isGenerating = false;
     
     @override
     Widget build(BuildContext context) {
       return AlertDialog(
         title: const Text('Share Document'),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             ListTile(
               leading: const Icon(Icons.link),
               title: const Text('Generate Share Link'),
               subtitle: _shareLink != null 
                 ? Text(_shareLink!)
                 : const Text('Create a temporary link to share'),
               trailing: _isGenerating 
                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                 : IconButton(
                     icon: const Icon(Icons.generate),
                     onPressed: _generateShareLink,
                   ),
             ),
             if (_shareLink != null)
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   TextButton.icon(
                     onPressed: () => ShareService.copyToClipboard(_shareLink!),
                     icon: const Icon(Icons.copy),
                     label: const Text('Copy'),
                   ),
                   TextButton.icon(
                     onPressed: () => Share.share(_shareLink!),
                     icon: const Icon(Icons.share),
                     label: const Text('Share'),
                   ),
                 ],
               ),
           ],
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(context),
             child: const Text('Close'),
           ),
         ],
       );
     }
     
     Future<void> _generateShareLink() async {
       setState(() => _isGenerating = true);
       
       try {
         final link = await ShareService.generateShareLink(widget.document);
         setState(() {
           _shareLink = link;
           _isGenerating = false;
         });
       } catch (e) {
         setState(() => _isGenerating = false);
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Failed to generate share link: $e')),
           );
         }
       }
     }
   }
   ```

#### Acceptance Criteria:
- ✅ Document sharing functionality implemented
- ✅ Share link generation for web
- ✅ Proper error handling
- ✅ Good user experience with progress indicators

---

## TESTING STRATEGY

For each fix:
1. Write unit tests for the specific functionality
2. Test on both web and mobile platforms
3. Test error scenarios and edge cases
4. Perform integration testing with related components
5. Test performance impact of changes

## ROLLBACK PLAN

- Create feature flags for major changes
- Implement fixes incrementally with backwards compatibility
- Keep detailed commit history for easy rollbacks
- Test in staging environment before production deployment
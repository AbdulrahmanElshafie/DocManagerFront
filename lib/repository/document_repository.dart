import 'dart:io';
import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:doc_manager/models/document.dart';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class DocumentRepository {
  final ApiService _apiService = ApiService();

  Future<Document> createDocument(
      String folderId, File file, String name) async {
    try {
      // Check if file extension is allowed
      final fileExt = path.extension(file.path).toLowerCase();
      if (fileExt != '.pdf' && fileExt != '.csv' && fileExt != '.docx') {
        throw Exception('Only PDF, CSV, and DOCX files are supported.');
      }
      
      // Verify file exists and is readable
      if (!file.existsSync()) {
        throw Exception('File does not exist at path: ${file.path}');
      }
      
      // Get file stats
      final fileSize = await file.length();
      final fileStat = await file.stat();
      
      // Log the file information
      developer.log('Creating document from file: ${file.path} with name: $name', name: 'DocumentRepository');
      developer.log('File exists: ${file.existsSync()}', name: 'DocumentRepository');
      developer.log('File size: $fileSize bytes, Last modified: ${fileStat.modified}', name: 'DocumentRepository');
      
      // If file is too large (> 10MB), make a copy with reduced size if possible
      if (fileSize > 10 * 1024 * 1024) {
        developer.log('File is large (${fileSize / (1024 * 1024)} MB), might cause upload issues', name: 'DocumentRepository');
      }
      
      // Try to create a local copy in temp directory
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(file.path);
      final tempFile = File('${tempDir.path}/$fileName');
      
      try {
        // Copy file to temp directory to avoid path issues
        await file.copy(tempFile.path);
        developer.log('Created temp copy at: ${tempFile.path}', name: 'DocumentRepository');
        
        // Use the temp file for upload
        final response = await _apiService.uploadFile(
          API.document, 
          tempFile,
          {
            'folder': folderId,
            'name': name,
          }
        );
        
        if (response == null || response.isEmpty) {
          throw Exception('Empty response received when creating document');
        }
        
        // Log successful upload
        developer.log('Document created successfully with response: $response', name: 'DocumentRepository');
        
        return Document.fromJson(response);
      } catch (e) {
        developer.log('Error uploading temp file: $e', name: 'DocumentRepository');
        
        // Fall back to original file if temp copy failed
        developer.log('Falling back to original file', name: 'DocumentRepository');
        final response = await _apiService.uploadFile(
          API.document, 
          file,
          {
            'folder': folderId,
            'name': name,
          }
        );
        
        if (response == null || response.isEmpty) {
          throw Exception('Empty response received when creating document');
        }
        
        return Document.fromJson(response);
      }
    } catch (e) {
      developer.log('Error creating document: $e', name: 'DocumentRepository');
      rethrow;
    }
  }

  // This method creates a document with content in the appropriate supported format
  Future<Document> createContentDocument({
    required String name,
    String? folderId,
    String? content
  }) async {
    try {
      if (content == null || content.isEmpty) {
        throw Exception('Content cannot be empty');
      }

      developer.log('Creating content document name: $name', name: 'DocumentRepository');
      
      // Use PDF as default format
      String fileExtension = '.pdf';
      DocumentType documentType = DocumentType.pdf;
      
      // Determine file type from name if possible
      if (name.toLowerCase().endsWith('.csv')) {
        fileExtension = '.csv';
        documentType = DocumentType.csv;
      } else if (name.toLowerCase().endsWith('.docx')) {
        fileExtension = '.docx';
        documentType = DocumentType.docx;
      } else if (!name.toLowerCase().endsWith('.pdf')) {
        // If no extension, append .pdf
        name = '$name.pdf';
      }
      
      developer.log('Creating content document: $name with type: $documentType', name: 'DocumentRepository');
      
      // For non-web platforms, we need to create a temporary file
      if (!kIsWeb) {
        try {
          final directory = await getTemporaryDirectory();
          final fileName = name.contains('.') ? name : '$name$fileExtension';
          final file = File('${directory.path}/$fileName');
          
          // Write content to the file
          await file.writeAsString(content);
          
          // Log file creation
          developer.log('Created temporary file at: ${file.path}', name: 'DocumentRepository');
          developer.log('File exists: ${file.existsSync()}', name: 'DocumentRepository');
          developer.log('File size: ${await file.length()} bytes', name: 'DocumentRepository');
          
          try {
            return await createDocument(folderId ?? '', file, name);
          } catch (e) {
            developer.log('Error in createDocument: $e', name: 'DocumentRepository');
            
            // Fall back to direct API call if createDocument fails
            final map = {
              'folder': folderId,
              'name': name,
              'content': content,
              'type': fileExtension.replaceAll('.', '')
            };
            
            developer.log('Falling back to direct API call with data: $map', name: 'DocumentRepository');
            final response = await _apiService.post(API.document, map, {});
            return Document.fromJson(response);
          }
        } catch (e) {
          developer.log('Error creating document with file: $e', name: 'DocumentRepository');
          
          // Fall back to direct API call
          final map = {
            'folder': folderId,
            'name': name,
            'content': content,
            'type': fileExtension.replaceAll('.', '')
          };
          
          developer.log('Falling back to direct API call with data: $map', name: 'DocumentRepository');
          final response = await _apiService.post(API.document, map, {});
          return Document.fromJson(response);
        }
      } else {
        // For web, use the API to create a document with content
        final map = {
          'folder': folderId,
          'name': name,
          'content': content,
          'type': fileExtension.replaceAll('.', '')
        };
        
        developer.log('Creating document with data: $map', name: 'DocumentRepository');
        final response = await _apiService.post(API.document, map, {});
        return Document.fromJson(response);
      }
    } catch (e) {
      developer.log('Error in createContentDocument: $e', name: 'DocumentRepository');
      rethrow;
    }
  }

  Future<List<Document>> getDocuments({String? folderId, String? query}) async {
    try {
      Map<String, dynamic> params = {};
      
      // Ensure we're explicitly filtering by folder ID
      // If folderId is null, we're getting root documents
      // If folderId has a value, we're getting documents in that specific folder
      if (folderId != null) {
        params['folder'] = folderId;
      } else {
        // For null folderId, explicitly set folder=null to get only root documents
        params['folder'] = 'null';
      }
      
      if (query != null && query.isNotEmpty) {
        params['query'] = query;
      }
      
      developer.log('Getting documents with params: $params', name: 'DocumentRepository');
      final response = await _apiService.getList(API.document, params);
      developer.log('Documents response: $response', name: 'DocumentRepository');
      
      final documents = response.map((e) => Document.fromJson(e)).toList();
      
      // Double-check that documents are properly filtered by folder
      if (folderId != null) {
        return documents.where((doc) => doc.folderId == folderId).toList();
      } else {
        // For root documents, ensure they don't have a parent folder
        return documents.where((doc) => doc.folderId.isEmpty).toList();
      }
    } catch (e) {
      developer.log('Error getting documents: $e', name: 'DocumentRepository');
      return [];
    }
  }

  Future<Map<String, dynamic>> deleteDocument(String id) async {
    final response = await _apiService.delete(API.document, id);
    return response;
  }

  Future<Map<String, dynamic>> updateDocument(
      String id, String folderId, File? file, String name, {String? content}) async {
    try {
      // Case 1: File is provided directly
      if (file != null) {
        // Check file extension
        final fileExt = path.extension(file.path).toLowerCase();
        if (fileExt != '.pdf' && fileExt != '.csv' && fileExt != '.docx') {
          throw Exception('Only PDF, CSV, and DOCX files are supported.');
        }
        
        // Log file information
        developer.log('Updating document with file: ${file.path} with name: $name', name: 'DocumentRepository');
        developer.log('File exists: ${file.existsSync()}', name: 'DocumentRepository');
        
        return await _apiService.updateFile(
          API.document,
          id,
          file,
          {
            'folder': folderId,
            'name': name,
          }
        );
      } 
      // Case 2: Content is provided, need to create a file with appropriate extension
      else if (content != null && !kIsWeb) {
        final directory = await getTemporaryDirectory();
        
        // Use appropriate extension based on current document name or default to PDF
        String fileExtension = '.pdf';
        if (name.toLowerCase().endsWith('.csv')) {
          fileExtension = '.csv';
        } else if (name.toLowerCase().endsWith('.docx')) {
          fileExtension = '.docx';
        }
        
        final fileName = name.contains('.') ? name : '$name$fileExtension';
        final tempFile = File('${directory.path}/$fileName');
        await tempFile.writeAsString(content);
        
        // Log file creation
        developer.log('Created temporary file for update at: ${tempFile.path}', name: 'DocumentRepository');
        developer.log('File exists: ${tempFile.existsSync()}', name: 'DocumentRepository');
        
        return await _apiService.updateFile(
          API.document,
          id,
          tempFile,
          {
            'folder': folderId,
            'name': name,
          }
        );
      }
      // Case 3: Web platform with content
      else if (kIsWeb && content != null) {
        // For web, we'll use a special multipart approach
        String fileExtension = '.pdf';
        if (name.toLowerCase().endsWith('.csv')) {
          fileExtension = '.csv';
        } else if (name.toLowerCase().endsWith('.docx')) {
          fileExtension = '.docx';
        }
        
        return await _apiService.updateFileFromBytes(
          API.document,
          id,
          utf8.encode(content),
          name.contains('.') ? name : '$name$fileExtension',
          {
            'folder': folderId,
            'name': name,
          }
        );
      }
      // Case 4: Just updating metadata, no content or file change
      else {
        return await _apiService.put(API.document, {
          'folder': folderId,
          'name': name,
        }, id);
      }
    } catch (e) {
      developer.log('Error updating document: $e', name: 'DocumentRepository');
      rethrow;
    }
  }

  Future<Document> getDocument(String id) async {
    try {
      // Ensure the URL is constructed correctly with the ID
      final response = await _apiService.get(API.document, {'id': id});
      
      developer.log('Document response for ID $id: $response', name: 'DocumentRepository');
      
      // Check for error or empty response
      if (response == null || response.isEmpty) {
        throw Exception('Empty document data received from API');
      }
      
      // Parse document
      final document = Document.fromJson(response);
      
      // // If document has a file path but no content, fetch the content
      // if (document.filePath != null && document.filePath!.isNotEmpty && document.file == null) {
      //   try {
      //     developer.log('Fetching content for document: ${document.filePath}', name: 'DocumentRepository');
      //
      //     // For file paths on the local system
      //     if (!document.filePath!.startsWith('http://') && !document.filePath!.startsWith('https://')) {
      //       try {
      //         // Normalize path for Windows if needed
      //         String normalizedPath = document.filePath!;
      //         if (!kIsWeb && Platform.isWindows) {
      //           normalizedPath = normalizedPath.replaceAll('\\', '/');
      //         }
      //
      //         final file = File(normalizedPath);
      //         if (file.existsSync()) {
      //           try {
      //             // Try to read content as text
      //             final fileContent = await file.readAsString();
      //             return document.copyWith(content: fileContent);
      //           } catch (e) {
      //             // Binary content that can't be read as text
      //             developer.log('Could not read file as text: $e', name: 'DocumentRepository');
      //             return document.copyWith(
      //               content: '[This document contains binary content that can only be viewed in the appropriate viewer.]'
      //             );
      //           }
      //         } else {
      //           developer.log('File does not exist: $normalizedPath', name: 'DocumentRepository');
      //           return document.copyWith(
      //             content: 'File not found: $normalizedPath'
      //           );
      //         }
      //       } catch (e) {
      //         developer.log('Error handling local file path: $e', name: 'DocumentRepository');
      //         return document.copyWith(
      //           content: 'Error handling file path: $e'
      //         );
      //       }
      //     } else {
      //       // Network file
      //       try {
      //         final uri = Uri.parse(document.filePath!);
      //         final contentResponse = await http.get(uri);
      //
      //         if (contentResponse.statusCode == 200) {
      //           // We got content, try to decode it based on document type
      //           String? content;
      //           try {
      //             // Get the temporary directory of the device
      //             final tempDir = await getTemporaryDirectory();
      //             final filePath = '${tempDir.path}/${document.name}.pdf';
      //
      //             // Write the binary data to a file
      //             final file = File(filePath);
      //             await file.writeAsBytes(contentResponse.bodyBytes);
      //             document.file = file;
      //           } catch (e) {
      //             developer.log('Failed to decode document content as UTF-8: $e', name: 'DocumentRepository');
      //             content = '[This document contains binary content that can only be viewed in the appropriate viewer.]';
      //           }
      //
      //           return document.copyWith(content: content);
      //         } else {
      //           developer.log('Failed to get document content: ${contentResponse.statusCode}', name: 'DocumentRepository');
      //           return document.copyWith(
      //             content: 'Failed to load document content. Status code: ${contentResponse.statusCode}'
      //           );
      //         }
      //       } catch (e) {
      //         developer.log('Error fetching document content: $e', name: 'DocumentRepository');
      //         return document.copyWith(
      //           content: 'Error loading document content: $e'
      //         );
      //       }
      //     }
      //   } catch (e) {
      //     developer.log('Error fetching document content: $e', name: 'DocumentRepository');
      //     return document.copyWith(
      //       content: 'Error loading document content: $e'
      //     );
      //   }
      // }
      //
      return document;
    } catch (e) {
      developer.log('Error getting document: $e', name: 'DocumentRepository');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> restoreVersion(String documentId, String versionId) async {
    final response = await _apiService.post(API.documentVersion, {
      'doc_id': documentId,
      'version_id': versionId,
    }, {
      'doc_id': documentId,
      'version_id': versionId,
    });
    return response;
  }
}

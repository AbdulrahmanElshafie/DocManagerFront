import 'package:flutter/material.dart';
import 'package:doc_manager/models/document.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class MetadataSection extends StatelessWidget {
  final Document document;
  
  const MetadataSection({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Document Metadata',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            // Document info rows
            _buildInfoRow('Name', document.name),
            _buildInfoRow('Type', _getDocumentTypeString(document.type)),
            _buildInfoRow('Created', document.createdAt.toString().split('.')[0]),
            _buildInfoRow('Last Modified', document.updatedAt?.toString().split('.')[0] ?? 'N/A'),
            _buildInfoRow('Owner ID', document.ownerId),
            _buildInfoRow('Folder ID', document.folderId),
            
            // // Show file size if available
            // if (document.size > 0)
            //   _buildInfoRow('Size', _formatFileSize(document.size)),
            //
            // Show file path if available
            if (document.filePath != null && document.filePath!.isNotEmpty)
              _buildInfoRow('Path', _formatFilePath(document.filePath!)),
              
            // Add file access status for local files
            if (document.filePath != null && document.filePath!.isNotEmpty && 
                !document.filePath!.startsWith('http://') && 
                !document.filePath!.startsWith('https://') &&
                !kIsWeb)
              _buildInfoRow(
                'Status', 
                File(document.filePath!).existsSync() ? 'Accessible' : 'Not Found'
              ),
          ],
        ),
      ),
    );
  }
  
  String _getDocumentTypeString(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return 'PDF Document';
      case DocumentType.docx:
        return 'Microsoft Word Document';
      case DocumentType.csv:
        return 'CSV Spreadsheet';
      default:
        return 'Unknown';
    }
  }
  
  String _formatFileSize(int sizeInBytes) {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(2)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
  
  String _formatFilePath(String path) {
    // Shorten long paths for display
    if (path.length > 40) {
      return '...${path.substring(path.length - 38)}';
    }
    return path;
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
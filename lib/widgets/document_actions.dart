import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/blocs/document/document_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/screens/shareable_links_screen.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:io' as io show File;
import 'package:share_plus/share_plus.dart';
import '../shared/utils/file_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DocumentActions extends StatelessWidget {
  final Document document;
  final Function onEdit;
  final Function onDelete;

  const DocumentActions({
    super.key,
    required this.document,
    required this.onEdit,
    required this.onDelete,
  });

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
              'Document Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            // Edit button
            _buildActionButton(
              context,
              icon: Icons.edit,
              label: 'Edit Document',
              onPressed: () => onEdit(),
            ),
            
            // Delete button
            _buildActionButton(
              context,
              icon: Icons.delete,
              label: 'Delete Document',
              onPressed: () => _confirmDelete(context),
              color: Colors.red,
            ),
            
            // Share button
            if (document.filePath != null && document.filePath!.isNotEmpty)
              _buildActionButton(
                context,
                icon: Icons.share,
                label: 'Share Document',
                onPressed: () => _shareDocument(context),
              ),
            
            // Download button
            if (document.filePath != null && document.filePath!.isNotEmpty)
              _buildActionButton(
                context,
                icon: Icons.download,
                label: 'Download Document',
                onPressed: () => _downloadDocument(context),
              ),
            
            // Shareable links button
            _buildActionButton(
              context,
              icon: Icons.link,
              label: 'Shareable Links',
              onPressed: () => _navigateToShareableLinks(context),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Function onPressed,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: () => onPressed(),
        style: ElevatedButton.styleFrom(
          foregroundColor: color != null 
              ? Colors.white
              : Theme.of(context).colorScheme.onPrimary,
          backgroundColor: color ?? Theme.of(context).colorScheme.primary,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
  
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  void _shareDocument(BuildContext context) {
    if (document.filePath != null && document.filePath!.isNotEmpty) {
      if (document.filePath!.startsWith('http://') || document.filePath!.startsWith('https://')) {
        // Share the URL
        Share.share(document.filePath!, subject: document.name);
      } else {
        // Share the local file
        io.File? file;
        if (!kIsWeb) {
          file = io.File(document.filePath!);
        }
        if (file != null && FileUtils.existsSync(file)) {
          Share.shareXFiles([XFile(document.filePath!)], subject: document.name);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File does not exist')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file path available to share')),
      );
    }
  }
  
  void _downloadDocument(BuildContext context) {
    // In a real app, this would download the document if it's remote
    // For local files, we would copy to Downloads folder
    
    if (document.filePath != null && document.filePath!.isNotEmpty) {
      if (document.filePath!.startsWith('http://') || document.filePath!.startsWith('https://')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download not implemented for remote files')),
        );
      } else {
        // For local files, indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File already available locally')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file available to download')),
      );
    }
  }
  

  
  void _navigateToShareableLinks(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShareableLinksScreen(documentId: document.id),
      ),
    );
  }
} 
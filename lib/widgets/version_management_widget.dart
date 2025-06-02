import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/document.dart';
import '../models/version.dart';
import '../blocs/version/version_bloc.dart';
import '../blocs/version/version_event.dart';
import '../blocs/version/version_state.dart';
import '../blocs/document/document_bloc.dart';
import '../blocs/document/document_event.dart';
import '../shared/utils/logger.dart';

class VersionManagementWidget extends StatefulWidget {
  final Document document;
  final VoidCallback? onVersionRestored;

  const VersionManagementWidget({
    super.key,
    required this.document,
    this.onVersionRestored,
  });

  @override
  State<VersionManagementWidget> createState() => _VersionManagementWidgetState();
}

class _VersionManagementWidgetState extends State<VersionManagementWidget> {
  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  void _loadVersions() {
    context.read<VersionBloc>().add(LoadVersions(widget.document.id));
  }

  void _restoreVersion(Version version) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to restore this version?'),
            const SizedBox(height: 16),
            Text('Version: ${version.versionNumber}'),
            Text('Created: ${_formatDate(version.createdAt)}'),
            Text('Modified by: ${version.modifiedBy}'),
            if (version.comment?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Comment: ${version.comment}'),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will replace the current document content with the selected version.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performRestore(version);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _performRestore(Version version) {
    context.read<DocumentBloc>().add(
      RestoreVersion(
        documentId: widget.document.id,
        versionId: version.versionId,
      ),
    );
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restoring version...'),
          ],
        ),
      ),
    );
  }

  void _createNewVersion() {
    final TextEditingController commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Create a new version of this document with the current content.'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Version comment (optional)',
                border: OutlineInputBorder(),
                hintText: 'Describe the changes made...',
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performCreateVersion(commentController.text);
            },
            child: const Text('Create Version'),
          ),
        ],
      ),
    ).then((_) => commentController.dispose());
  }

  void _performCreateVersion(String comment) {
    // Note: This would need to be implemented in the backend
    // For now, we'll just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Version creation functionality to be implemented'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildVersionTile(Version version, bool isLatest) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLatest ? Colors.green : Colors.grey,
          child: Text(
            'v${version.versionNumber}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        title: Row(
          children: [
            Text('Version ${version.versionNumber}'),
            if (isLatest) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'CURRENT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Created: ${_formatDate(version.createdAt)}'),
            Text('Modified by: ${version.modifiedBy}'),
            if (version.size > 0) Text('Size: ${_formatFileSize(version.size)}'),
            if (version.comment?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                version.comment!,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                // TODO: Implement version preview
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Version preview to be implemented'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              tooltip: 'Preview version',
            ),
            if (!isLatest)
              IconButton(
                icon: const Icon(Icons.restore),
                onPressed: () => _restoreVersion(version),
                tooltip: 'Restore this version',
              ),
          ],
        ),
        isThreeLine: version.comment?.isNotEmpty == true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.history),
              const SizedBox(width: 8),
              const Text(
                'Document Versions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _createNewVersion,
                icon: const Icon(Icons.add),
                label: const Text('Create Version'),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadVersions,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        
        // Versions list
        Expanded(
          child: BlocBuilder<VersionBloc, VersionState>(
            builder: (context, state) {
              if (state is VersionsLoading) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading versions...'),
                    ],
                  ),
                );
              } else if (state is VersionError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${state.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadVersions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              } else if (state is VersionsLoaded) {
                final versions = state.versions;
                
                if (versions.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No versions available'),
                        SizedBox(height: 8),
                        Text(
                          'Create a version to save the current state of the document.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: versions.length,
                  itemBuilder: (context, index) {
                    final version = versions[index];
                    final isLatest = index == 0; // Assuming versions are sorted by date desc
                    return _buildVersionTile(version, isLatest);
                  },
                );
              } else {
                return const Center(
                  child: Text('No version data'),
                );
              }
            },
          ),
        ),
      ],
    );
  }
} 
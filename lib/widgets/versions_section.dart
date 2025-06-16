import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/models/version.dart';
import 'package:doc_manager/blocs/version/version_bloc.dart';
import 'package:doc_manager/blocs/version/version_event.dart';
import 'package:doc_manager/blocs/version/version_state.dart';
import 'package:doc_manager/blocs/document/document_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';

class VersionsSection extends StatefulWidget {
  final String documentId;
  
  const VersionsSection({super.key, required this.documentId});

  @override
  State<VersionsSection> createState() => _VersionsSectionState();
}

class _VersionsSectionState extends State<VersionsSection> {
  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  void _loadVersions() {
    context.read<VersionBloc>().add(LoadVersions(widget.documentId));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocConsumer<VersionBloc, VersionState>(
          listener: (context, state) {
            if (state is VersionError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.error}'),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (state is VersionOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
              _loadVersions(); // Reload versions after successful operation
            }
          },
          builder: (context, state) {
            if (state is VersionLoading) {
              return const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.history),
                      SizedBox(width: 8),
                      Text(
                        'Document Versions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            } else if (state is VersionError) {
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.history),
                          SizedBox(width: 8),
                          Text(
                            'Document Versions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadVersions,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text('Error loading versions: ${state.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadVersions,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            } else if (state is VersionsLoaded) {
              return _buildVersionsList(state.versions);
            }
            
            return _buildVersionsList([]);
          },
        ),
      ),
    );
  }
  
  Widget _buildVersionsList(List<Version> versions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 8),
                Text(
                  'Document Versions (${versions.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadVersions,
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Version'),
                  onPressed: () => _createNewVersion(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Versions list
        if (versions.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No versions available',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create your first version to track changes',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: versions.asMap().entries.map((entry) {
              final index = entry.key;
              final version = entry.value;
              final isLatest = index == 0;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isLatest ? Colors.green : Colors.grey.shade300,
                    width: isLatest ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isLatest ? Colors.green.shade50 : null,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLatest ? Colors.green : Colors.blue,
                    child: Text(
                      'v${version.versionNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
                      Text(
                        'Created: ${_formatDate(version.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (version.modifiedBy.isNotEmpty)
                        Text(
                          'Modified by: ${version.modifiedBy}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (version.comment != null && version.comment!.isNotEmpty)
                        Text(
                          'Comment: ${version.comment}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (version.size > 0)
                        Text(
                          'Size: ${_formatFileSize(version.size)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        tooltip: 'View details',
                        onPressed: () => _showVersionDetails(version, index),
                      ),
                      if (!isLatest)
                        IconButton(
                          icon: const Icon(Icons.restore, size: 20),
                          tooltip: 'Restore this version',
                          onPressed: () => _restoreVersion(version),
                        ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onPressed: () => _showVersionOptions(version, index),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _createNewVersion() {
    showDialog(
      context: context,
      builder: (context) => _CreateVersionDialog(documentId: widget.documentId),
    );
  }

  void _showVersionDetails(Version version, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Version ${version.versionNumber} Details'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Version Number', version.versionNumber.toString()),
                _buildDetailRow('Created', _formatDate(version.createdAt)),
                if (version.lastModified != null)
                  _buildDetailRow('Last Modified', _formatDate(version.lastModified!)),
                _buildDetailRow('Modified By', version.modifiedBy),
                if (version.comment != null && version.comment!.isNotEmpty)
                  _buildDetailRow('Comment', version.comment!),
                _buildDetailRow('Size', _formatFileSize(version.size)),
                _buildDetailRow('Document ID', version.id),
                _buildDetailRow('Version ID', version.versionId),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (index > 0) // Not the current version
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _restoreVersion(version);
              },
              child: const Text('Restore This Version'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showVersionOptions(Version version, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Version ${version.versionNumber} Options',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showVersionDetails(version, index);
              },
            ),
            if (index > 0) // Not the current version
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore Version'),
                onTap: () {
                  Navigator.pop(context);
                  _restoreVersion(version);
                },
              ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download Version'),
              onTap: () {
                Navigator.pop(context);
                _downloadVersion(version);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _restoreVersion(Version version) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Version'),
        content: Text(
          'Are you sure you want to restore Version ${version.versionNumber}?\n\n'
          'This will replace the current document content with the content from this version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DocumentBloc>().add(RestoreVersion(
                documentId: widget.documentId,
                versionId: version.versionId,
              ));
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _downloadVersion(Version version) {
    // Implement download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download functionality will be implemented'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}

class _CreateVersionDialog extends StatefulWidget {
  final String documentId;

  const _CreateVersionDialog({required this.documentId});

  @override
  State<_CreateVersionDialog> createState() => _CreateVersionDialogState();
}

class _CreateVersionDialogState extends State<_CreateVersionDialog> {
  final TextEditingController _commentController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Version'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create a new version of the current document state.'),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'Version Comment (Optional)',
              hintText: 'Describe what changed in this version...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createVersion,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  void _createVersion() {
    setState(() {
      _isCreating = true;
    });

    context.read<VersionBloc>().add(
      CreateVersion(
        documentId: widget.documentId,
        versionId: '', // Will be generated by the backend
        comment: _commentController.text.trim().isEmpty 
            ? null 
            : _commentController.text.trim(),
      ),
    );

    Navigator.pop(context);
  }
} 
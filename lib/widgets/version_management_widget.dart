import 'package:flutter/material.dart';
import '../models/document.dart';
import '../shared/utils/logger.dart';
import '../shared/network/api_service.dart';
import '../shared/utils/file_utils.dart';

class VersionManagementWidget extends StatefulWidget {
  final Document document;

  const VersionManagementWidget({
    super.key,
    required this.document,
  });

  @override
  State<VersionManagementWidget> createState() => _VersionManagementWidgetState();
}

class _VersionManagementWidgetState extends State<VersionManagementWidget> {
  final ApiService _apiService = ApiService();
  List<DocumentVersion> _versions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await _apiService.get(
        '/manager/document/revision/${widget.document.id}/',
        {},
      );

      setState(() {
        _versions = (response as List)
            .map((v) => DocumentVersion.fromJson(v))
            .toList();
      });
    } catch (e) {
      LoggerUtil.error('Error loading versions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading versions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreVersion(DocumentVersion version) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _apiService.post(
        '/manager/document/revision/${widget.document.id}/${version.id}/',
        {},
        {'doc_id': widget.document.id, 'version_id': version.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Version restored successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate refresh needed
      }
    } catch (e) {
      LoggerUtil.error('Error restoring version: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring version: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _viewVersion(DocumentVersion version) async {
    try {
      final response = await _apiService.get(
        '/manager/document/revision/${widget.document.id}/${version.id}/',
        {'doc_id': widget.document.id, 'version_id': version.id},
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => VersionViewDialog(
            version: version,
            document: Document.fromJson(response),
          ),
        );
      }
    } catch (e) {
      LoggerUtil.error('Error viewing version: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error viewing version: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRestoreConfirmDialog(DocumentVersion version) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Version'),
        content: Text(
          'Are you sure you want to restore this version?\n\n'
          'Created: ${_formatDate(version.createdAt)}\n'
          'This will create a new version with the restored content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreVersion(version);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
              IconButton(
                onPressed: _loadVersions,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh versions',
              ),
            ],
          ),
        ),

        // Version list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _versions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _versions.length,
                      itemBuilder: (context, index) {
                        final version = _versions[index];
                        final isLatest = index == 0;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isLatest
                                  ? Colors.green
                                  : Colors.blue,
                              child: Text(
                                '${_versions.length - index}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text('Version ${_versions.length - index}'),
                                if (isLatest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
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
                                if (version.comment?.isNotEmpty == true)
                                  Text(
                                    'Note: ${version.comment}',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () => _viewVersion(version),
                                  tooltip: 'View version',
                                ),
                                if (!isLatest)
                                  IconButton(
                                    icon: const Icon(Icons.restore),
                                    onPressed: () => _showRestoreConfirmDialog(version),
                                    tooltip: 'Restore this version',
                                    color: Colors.blue,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class VersionViewDialog extends StatelessWidget {
  final DocumentVersion version;
  final Document document;

  const VersionViewDialog({
    super.key,
    required this.version,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Version ${version.id}'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Created: ${_formatDate(version.createdAt)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (version.comment?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Comment: ${version.comment}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Document Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${document.name}'),
                      Text('Type: ${document.type.name}'),
                      Text('Size: ${document.file != null ? FileUtils.lengthSync(document.file!) : 0} bytes'),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: This is a preview of the version. The actual file content is preserved.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class DocumentVersion {
  final String id;
  final DateTime createdAt;
  final String? comment;

  DocumentVersion({
    required this.id,
    required this.createdAt,
    this.comment,
  });

  factory DocumentVersion.fromJson(Map<String, dynamic> json) {
    return DocumentVersion(
      id: json['id'].toString(),
      createdAt: DateTime.parse(json['created_at'] ?? json['updated_at']),
      comment: json['comment'],
    );
  }
} 
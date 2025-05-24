import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/backup/backup_bloc.dart';
import 'package:doc_manager/blocs/backup/backup_event.dart';
import 'package:doc_manager/blocs/backup/backup_state.dart';
import 'package:doc_manager/blocs/document/document_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/blocs/document/document_state.dart';
import 'package:doc_manager/models/backup.dart';
import 'package:doc_manager/models/document.dart';

class BackupsScreen extends StatefulWidget {
  final String? documentId; // Optional - if null, shows all backups
  
  const BackupsScreen({super.key, this.documentId});

  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> {
  @override
  void initState() {
    super.initState();
    _loadBackups();
  }
  
  void _loadBackups() {
    if (widget.documentId != null) {
      context.read<BackupBloc>().add(GetBackupsByDocument(documentId: widget.documentId!));
    } else {
      context.read<BackupBloc>().add(GetAllBackups());
    }
  }
  
  void _createBackup([String? specificDocumentId]) {
    // According to API docs, backup creation doesn't require document selection
    // Just create backup directly
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Backup'),
        content: const Text('Do you want to create a new backup? This will backup the current system state.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<BackupBloc>().add(CreateBackup());
              Navigator.pop(context);
            },
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );
  }

  void _showDocumentSelectionDialog() {
    // Load all documents first
    context.read<DocumentBloc>().add(const LoadDocuments());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Backup'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: BlocBuilder<DocumentBloc, DocumentState>(
            builder: (context, state) {
              if (state is DocumentsLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is DocumentsLoaded) {
                final documents = state.documents;
                
                if (documents.isEmpty) {
                  return const Center(
                    child: Text('No documents available for backup'),
                  );
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select a document to backup:'),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: documents.length,
                        itemBuilder: (context, index) {
                          final document = documents[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getDocumentTypeColor(document.type).withValues(alpha: 0.1),
                              child: Icon(
                                _getDocumentTypeIcon(document.type),
                                color: _getDocumentTypeColor(document.type),
                                size: 20,
                              ),
                            ),
                            title: Text(document.name),
                            subtitle: Text(_formatDocumentType(document.type)),
                            onTap: () {
                              Navigator.pop(context); // Close dialog
                              _createBackupForDocument(document);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              } else if (state is DocumentError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Error loading documents: ${state.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<DocumentBloc>().add(const LoadDocuments());
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              
              return const Center(child: Text('Loading documents...'));
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _createBackupForDocument(Document document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create a backup for:'),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  _getDocumentTypeIcon(document.type),
                  color: _getDocumentTypeColor(document.type),
                ),
                title: Text(document.name),
                subtitle: Text(_formatDocumentType(document.type)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('This will create a system backup.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<BackupBloc>().add(CreateBackup());
              Navigator.pop(context);
            },
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.csv:
        return Icons.table_chart;
      case DocumentType.docx:
        return Icons.description;
      case DocumentType.unsupported:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Colors.red;
      case DocumentType.csv:
        return Colors.green;
      case DocumentType.docx:
        return Colors.blue;
      case DocumentType.unsupported:
        return Colors.grey;
    }
  }

  String _formatDocumentType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return 'PDF Document';
      case DocumentType.csv:
        return 'CSV Spreadsheet';
      case DocumentType.docx:
        return 'Word Document';
      case DocumentType.unsupported:
        return 'Unknown';
    }
  }
  
  void _restoreBackup(Backup backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Text('Are you sure you want to restore this backup from ${backup.createdAt.toString().split('.')[0]}?\n\nThis will overwrite the current document content.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<BackupBloc>().add(RestoreBackup(id: backup.id));
              Navigator.pop(context);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
  
  void _deleteBackup(Backup backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Are you sure you want to delete this backup from ${backup.createdAt.toString().split('.')[0]}?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<BackupBloc>().add(DeleteBackup(id: backup.id));
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.documentId == null ? 'All Backups' : 'Document Backups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBackups,
          ),
          if (widget.documentId == null)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create New Backup',
              onPressed: () => _createBackup(),
            ),
        ],
      ),
      body: BlocConsumer<BackupBloc, BackupState>(
        listener: (context, state) {
          if (state is BackupError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.error}'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is BackupSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            _loadBackups();
          }
        },
        builder: (context, state) {
          if (state is BackupLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is BackupsLoaded) {
            final backups = state.backups;
            
            if (backups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.backup,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No backups found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Create your first backup to get started'),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _createBackup(),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Backup'),
                    ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.backup, color: Colors.white),
                    ),
                    title: Text('Backup ${index + 1}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Document ID: ${backup.documentId}'),
                        Text(
                          'Created: ${backup.createdAt.toString().split('.')[0]}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.restore, color: Colors.blue),
                          tooltip: 'Restore',
                          onPressed: () => _restoreBackup(backup),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _deleteBackup(backup),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            );
          }
          
          return const Center(child: Text('Loading backups...'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createBackup(),
        icon: const Icon(Icons.add),
        label: const Text('Create Backup'),
        tooltip: 'Create New Backup',
      ),
    );
  }
} 
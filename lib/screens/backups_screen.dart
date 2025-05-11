import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/backup/backup_bloc.dart';
import 'package:doc_manager/blocs/backup/backup_event.dart';
import 'package:doc_manager/blocs/backup/backup_state.dart';
import 'package:doc_manager/models/backup.dart';

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
  
  void _createBackup() {
    if (widget.documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document to backup')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Backup'),
        content: const Text('Do you want to create a backup of this document?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<BackupBloc>().add(CreateBackup(documentId: widget.documentId!));
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
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
        ],
      ),
      body: BlocConsumer<BackupBloc, BackupState>(
        listener: (context, state) {
          if (state is BackupError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.error}')),
            );
          } else if (state is BackupSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
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
                    const Text('No backups found'),
                    const SizedBox(height: 16),
                    if (widget.documentId != null)
                      ElevatedButton(
                        onPressed: _createBackup,
                        child: const Text('Create Backup'),
                      ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.backup),
                  ),
                  title: Text('Backup ${index + 1}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Document ID: ${backup.documentId}'),
                      Text('Created: ${backup.createdAt.toString().split('.')[0]}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: 'Restore',
                        onPressed: () {
                          _restoreBackup(backup);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete',
                        onPressed: () {
                          _deleteBackup(backup);
                        },
                      ),
                    ],
                  ),
                  isThreeLine: true,
                );
              },
            );
          }
          
          return const Center(child: Text('Select a document to view backups'));
        },
      ),
      floatingActionButton: widget.documentId != null
          ? FloatingActionButton(
              onPressed: _createBackup,
              tooltip: 'Create Backup',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/document.dart';
import '../models/folder.dart';
import '../models/permission.dart';
import '../blocs/permission/permission_bloc.dart';
import '../blocs/permission/permission_event.dart';
import '../blocs/permission/permission_state.dart';
import '../shared/utils/logger.dart';

class PermissionManagementWidget extends StatefulWidget {
  final Document? document;
  final Folder? folder;
  final VoidCallback? onPermissionChanged;

  const PermissionManagementWidget({
    super.key,
    this.document,
    this.folder,
    this.onPermissionChanged,
  });

  @override
  State<PermissionManagementWidget> createState() => _PermissionManagementWidgetState();
}

class _PermissionManagementWidgetState extends State<PermissionManagementWidget> {
  final TextEditingController _userSearchController = TextEditingController();
  String _selectedPermissionLevel = 'read';
  
  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    super.dispose();
  }

  void _loadPermissions() {
    context.read<PermissionBloc>().add(const LoadPermissions());
  }

  String get _resourceType {
    return widget.document != null ? 'Document' : 'Folder';
  }

  String get _resourceName {
    return widget.document?.name ?? widget.folder?.name ?? 'Unknown';
  }

  String get _resourceId {
    return widget.document?.id ?? widget.folder?.id ?? '';
  }

  void _showAddPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddPermissionDialog(
        document: widget.document,
        folder: widget.folder,
        onPermissionAdded: () {
          _loadPermissions();
          widget.onPermissionChanged?.call();
        },
      ),
    );
  }

  void _editPermission(Permission permission) {
    showDialog(
      context: context,
      builder: (context) => _EditPermissionDialog(
        permission: permission,
        document: widget.document,
        folder: widget.folder,
        onPermissionUpdated: () {
          _loadPermissions();
          widget.onPermissionChanged?.call();
        },
      ),
    );
  }

  void _deletePermission(Permission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Permission'),
        content: Text(
          'Are you sure you want to remove permission for this user?\n\n'
          'User: ${permission.userId}\n'
          'Current level: ${permission.level}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PermissionBloc>().add(
                DeletePermission(id: permission.id),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Color _getPermissionLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'read':
        return Colors.blue;
      case 'write':
        return Colors.orange;
      case 'delete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getPermissionLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'read':
        return Icons.visibility;
      case 'write':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      default:
        return Icons.help;
    }
  }

  Widget _buildPermissionTile(Permission permission) {
    final color = _getPermissionLevelColor(permission.level);
    final icon = _getPermissionLevelIcon(permission.level);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(permission.userId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Permission: ${permission.level.toUpperCase()}'),
            Text('Type: ${permission.permissionType}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editPermission(permission),
              tooltip: 'Edit permission',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deletePermission(permission),
              tooltip: 'Remove permission',
              color: Colors.red,
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PermissionBloc, PermissionState>(
      listener: (context, state) {
        if (state is PermissionOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          _loadPermissions();
          widget.onPermissionChanged?.call();
        } else if (state is PermissionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security),
                    const SizedBox(width: 8),
                    const Text(
                      'Permissions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showAddPermissionDialog,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add User'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _loadPermissions,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$_resourceType: $_resourceName',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),

          // Permissions info
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Permission Levels:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue, size: 16),
                    const SizedBox(width: 4),
                    const Text('Read: View content'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    const Text('Write: View and edit content'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    const Text('Delete: Full access including deletion'),
                  ],
                ),
              ],
            ),
          ),

          // Permissions list
          Expanded(
            child: BlocBuilder<PermissionBloc, PermissionState>(
              builder: (context, state) {
                if (state is PermissionLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading permissions...'),
                      ],
                    ),
                  );
                } else if (state is PermissionError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${state.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPermissions,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (state is PermissionsLoaded) {
                  // Filter permissions for this resource
                  final permissions = state.permissions.where((p) {
                    if (widget.document != null) {
                      return p.documentId == widget.document!.id;
                    } else if (widget.folder != null) {
                      return p.folderId == widget.folder!.id;
                    }
                    return false;
                  }).toList();

                  if (permissions.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No permissions set'),
                          SizedBox(height: 8),
                          Text(
                            'Add users to share this document or folder.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: permissions.length,
                    itemBuilder: (context, index) {
                      return _buildPermissionTile(permissions[index]);
                    },
                  );
                } else {
                  return const Center(
                    child: Text('No permission data'),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPermissionDialog extends StatefulWidget {
  final Document? document;
  final Folder? folder;
  final VoidCallback onPermissionAdded;

  const _AddPermissionDialog({
    this.document,
    this.folder,
    required this.onPermissionAdded,
  });

  @override
  State<_AddPermissionDialog> createState() => _AddPermissionDialogState();
}

class _AddPermissionDialogState extends State<_AddPermissionDialog> {
  final TextEditingController _userIdController = TextEditingController();
  String _selectedLevel = 'read';
  bool _isLoading = false;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  void _addPermission() async {
    if (_userIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a user ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      context.read<PermissionBloc>().add(
        CreatePermission(
          userId: _userIdController.text.trim(),
          documentId: widget.document?.id,
          folderId: widget.folder?.id,
          level: _selectedLevel,
        ),
      );

      Navigator.pop(context);
      widget.onPermissionAdded();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Permission'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
              labelText: 'User ID / Email',
              border: OutlineInputBorder(),
              hintText: 'Enter user identifier',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedLevel,
            decoration: const InputDecoration(
              labelText: 'Permission Level',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'read', child: Text('Read')),
              DropdownMenuItem(value: 'write', child: Text('Write')),
              DropdownMenuItem(value: 'delete', child: Text('Delete')),
            ],
            onChanged: _isLoading ? null : (value) {
              setState(() {
                _selectedLevel = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addPermission,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

class _EditPermissionDialog extends StatefulWidget {
  final Permission permission;
  final Document? document;
  final Folder? folder;
  final VoidCallback onPermissionUpdated;

  const _EditPermissionDialog({
    required this.permission,
    this.document,
    this.folder,
    required this.onPermissionUpdated,
  });

  @override
  State<_EditPermissionDialog> createState() => _EditPermissionDialogState();
}

class _EditPermissionDialogState extends State<_EditPermissionDialog> {
  late String _selectedLevel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.permission.level;
  }

  void _updatePermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      context.read<PermissionBloc>().add(
        UpdatePermission(
          id: widget.permission.id,
          userId: widget.permission.userId,
          documentId: widget.document?.id,
          folderId: widget.folder?.id,
          level: _selectedLevel,
        ),
      );

      Navigator.pop(context);
      widget.onPermissionUpdated();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Permission'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('User: ${widget.permission.userId}'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedLevel,
            decoration: const InputDecoration(
              labelText: 'Permission Level',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'read', child: Text('Read')),
              DropdownMenuItem(value: 'write', child: Text('Write')),
              DropdownMenuItem(value: 'delete', child: Text('Delete')),
            ],
            onChanged: _isLoading ? null : (value) {
              setState(() {
                _selectedLevel = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updatePermission,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
} 
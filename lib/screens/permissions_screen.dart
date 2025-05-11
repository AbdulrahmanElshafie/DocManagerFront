import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/permission/permission_bloc.dart';
import 'package:doc_manager/blocs/permission/permission_event.dart';
import 'package:doc_manager/blocs/permission/permission_state.dart';
import 'package:doc_manager/blocs/user/user_bloc.dart';
import 'package:doc_manager/blocs/user/user_event.dart';
import 'package:doc_manager/blocs/user/user_state.dart';
import 'package:doc_manager/models/permission.dart';
import 'package:doc_manager/models/user.dart';

class PermissionsScreen extends StatefulWidget {
  final String documentId;
  
  const PermissionsScreen({super.key, required this.documentId});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPermissionType;
  List<User> _searchResults = [];
  
  @override
  void initState() {
    super.initState();
    context.read<PermissionBloc>().add(GetPermissions(resourceId: widget.documentId));
    context.read<UserBloc>().add(LoadUsers());
  }
  
  void _showAddPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Permission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search User',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _searchUsers(value);
              },
            ),
            const SizedBox(height: 8),
            if (_searchResults.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text('${_searchResults[index].firstName} ${_searchResults[index].lastName}'),
                      subtitle: Text(_searchResults[index].email),
                      onTap: () {
                        Navigator.pop(context);
                        _showPermissionTypeDialog(_searchResults[index]);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _searchUsers(String query) {
    final userState = context.read<UserBloc>().state;
    if (userState is UsersLoaded) {
      setState(() {
        _searchResults = userState.users
            .where((user) =>
                user.firstName.toLowerCase().contains(query.toLowerCase()) ||
                user.lastName.toLowerCase().contains(query.toLowerCase()) ||
                user.email.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }
  
  void _showPermissionTypeDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Permission Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Read'),
                value: 'read',
                groupValue: _selectedPermissionType,
                onChanged: (value) {
                  setState(() {
                    _selectedPermissionType = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Write'),
                value: 'write',
                groupValue: _selectedPermissionType,
                onChanged: (value) {
                  setState(() {
                    _selectedPermissionType = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Admin'),
                value: 'admin',
                groupValue: _selectedPermissionType,
                onChanged: (value) {
                  setState(() {
                    _selectedPermissionType = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _selectedPermissionType == null
                  ? null
                  : () {
                      context.read<PermissionBloc>().add(
                        CreatePermission(
                          resourceId: widget.documentId,
                          userId: user.id.toString(),
                          permissionType: _selectedPermissionType!,
                          level: _selectedPermissionType!,
                          documentId: widget.documentId,
                        ),
                      );
                      Navigator.pop(context);
                      _selectedPermissionType = null;
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showEditPermissionDialog(Permission permission) {
    _selectedPermissionType = permission.permissionType;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Permission'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Read'),
                value: 'read',
                groupValue: _selectedPermissionType,
                onChanged: (value) {
                  setState(() {
                    _selectedPermissionType = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Write'),
                value: 'write',
                groupValue: _selectedPermissionType,
                onChanged: (value) {
                  setState(() {
                    _selectedPermissionType = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Admin'),
                value: 'admin',
                groupValue: _selectedPermissionType,
                onChanged: (value) {
                  setState(() {
                    _selectedPermissionType = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _selectedPermissionType = null;
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<PermissionBloc>().add(
                  UpdatePermission(
                    id: permission.id,
                    permissionType: _selectedPermissionType!,
                    userId: permission.userId,
                    level: _selectedPermissionType!,
                    documentId: widget.documentId,
                  ),
                );
                Navigator.pop(context);
                _selectedPermissionType = null;
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDeletePermissionDialog(Permission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permission'),
        content: const Text('Are you sure you want to remove this permission?'),
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
              context.read<PermissionBloc>().add(DeletePermission(id: permission.id));
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
        title: const Text('Permissions'),
      ),
      body: BlocConsumer<PermissionBloc, PermissionState>(
        listener: (context, state) {
          if (state is PermissionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.error}')),
            );
          } else if (state is PermissionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            // Refresh permissions after operation
            context.read<PermissionBloc>().add(GetPermissions(resourceId: widget.documentId));
          }
        },
        builder: (context, state) {
          if (state is PermissionLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is PermissionsLoaded) {
            final permissions = state.permissions;
            
            if (permissions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No permissions found'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _showAddPermissionDialog,
                      child: const Text('Add Permission'),
                    ),
                  ],
                ),
              );
            }
            
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Manage who can access this document',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: permissions.length,
                    itemBuilder: (context, index) {
                      final permission = permissions[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(permission.userId.substring(0, 1).toUpperCase()),
                        ),
                        title: Text(permission.userId),
                        subtitle: Text('Permission: ${_formatPermissionType(permission.permissionType)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                _showEditPermissionDialog(permission);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                _showDeletePermissionDialog(permission);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
          
          return const Center(child: Text('Select a document to manage permissions'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPermissionDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
  
  String _formatPermissionType(String type) {
    switch (type) {
      case 'read':
        return 'Read';
      case 'write':
        return 'Write';
      case 'admin':
        return 'Admin';
      default:
        return type;
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
} 
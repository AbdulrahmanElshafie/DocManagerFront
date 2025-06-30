import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/shareable_link/shareable_link_bloc.dart';
import 'package:doc_manager/blocs/shareable_link/shareable_link_event.dart';
import 'package:doc_manager/blocs/shareable_link/shareable_link_state.dart';
import 'package:doc_manager/models/shareable_link.dart';

class ShareableLinksScreen extends StatefulWidget {
  final String? documentId; // Optional - if null, shows all links
  
  const ShareableLinksScreen({super.key, this.documentId});

  @override
  State<ShareableLinksScreen> createState() => _ShareableLinksScreenState();
}

class _ShareableLinksScreenState extends State<ShareableLinksScreen> {
  DateTime? _expiryDate;
  String? _selectedPermissionType;
  
  @override
  void initState() {
    super.initState();
    if (widget.documentId != null) {
      context.read<ShareableLinkBloc>().add(GetShareableLinks(resourceId: widget.documentId!));
    } else {
      // Load all shareable links
      context.read<ShareableLinkBloc>().add(const LoadShareableLinks());
    }
  }
  
  void _showCreateLinkDialog() {
    _expiryDate = DateTime.now().add(const Duration(days: 7)); // Default to 7 days
    _selectedPermissionType = 'read'; // Default to read permission
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Shareable Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Permission Type:'),
              RadioListTile<String>(
                title: const Text('Read Only'),
                value: 'read',
                groupValue: _selectedPermissionType,
                onChanged: (value) {
                  setState(() {
                    _selectedPermissionType = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Read & Write'),
                value: 'write',
                groupValue: _selectedPermissionType,
                onChanged: (value) {
                  setState(() {
                    _selectedPermissionType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('Expiry Date:'),
              ListTile(
                title: Text(
                  _expiryDate != null
                      ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                      : 'Select Date',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _expiryDate = pickedDate;
                    });
                  }
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
              onPressed: () {
                if (widget.documentId != null) {
                  context.read<ShareableLinkBloc>().add(
                    CreateShareableLink(
                      resourceId: widget.documentId!,
                      permissionType: _selectedPermissionType!,
                      expiresAt: _expiryDate!,
                      documentId: widget.documentId!,
                    ),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No document selected')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDeleteLinkDialog(ShareableLink link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shareable Link'),
        content: const Text('Are you sure you want to delete this link? Anyone using it will no longer have access.'),
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
              context.read<ShareableLinkBloc>().add(DeleteShareableLink(id: link.id));
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  void _copyLinkToClipboard(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shareable Links'),
      ),
      body: BlocConsumer<ShareableLinkBloc, ShareableLinkState>(
        listener: (context, state) {
          if (state is ShareableLinkError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.error}')),
            );
                      } else if (state is ShareableLinkSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
              // Refresh links after operation
              if (widget.documentId != null) {
                context.read<ShareableLinkBloc>().add(GetShareableLinks(resourceId: widget.documentId!));
              } else {
                context.read<ShareableLinkBloc>().add(const LoadShareableLinks());
              }
            }
        },
        builder: (context, state) {
          if (state is ShareableLinkLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ShareableLinksLoaded) {
            final links = state.links;
            
            if (links.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No shareable links found'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _showCreateLinkDialog,
                      child: const Text('Create Shareable Link'),
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
                    'Manage shareable links for this document',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: links.length,
                    itemBuilder: (context, index) {
                      final link = links[index];
                      final isExpired = link.expiryDate.isBefore(DateTime.now());
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.link),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      link.token,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isExpired ? Colors.grey : null,
                                        decoration: isExpired ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: isExpired
                                        ? null
                                        : () => _copyLinkToClipboard('https://example.com/share/${link.token}'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Permission: ${_formatPermissionType(link.permissionType)}'),
                              Text(
                                'Expires: ${link.expiryDate.toString().split(' ')[0]}',
                                style: TextStyle(
                                  color: isExpired ? Colors.red : null,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      _showDeleteLinkDialog(link);
                                    },
                                    child: const Text('Delete'),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  ),
                                ],
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
          
          return const Center(child: Text('Select a document to manage shareable links'));
        },
      ),
      floatingActionButton: widget.documentId != null ? FloatingActionButton(
        onPressed: _showCreateLinkDialog,
        child: const Icon(Icons.add_link),
      ) : null,
    );
  }
  
  String _formatPermissionType(String type) {
    switch (type) {
      case 'read':
        return 'Read Only';
      case 'write':
        return 'Read & Write';
      default:
        return type;
    }
  }
} 
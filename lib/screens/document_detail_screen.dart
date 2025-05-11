import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// Document viewer packages - specific versions as required
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:docx_template/docx_template.dart' hide Border;
import 'package:excel/excel.dart' hide Border;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/models/version.dart';
import 'package:doc_manager/models/comment.dart';
import 'package:doc_manager/blocs/document/document_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/blocs/document/document_state.dart';
import 'package:doc_manager/blocs/version/version_bloc.dart';
import 'package:doc_manager/blocs/version/version_event.dart';
import 'package:doc_manager/blocs/version/version_state.dart';
import 'package:doc_manager/blocs/comment/comment_bloc.dart';
import 'package:doc_manager/blocs/comment/comment_event.dart';
import 'package:doc_manager/blocs/comment/comment_state.dart';
import 'package:doc_manager/widgets/comments_section.dart';
import 'package:doc_manager/widgets/versions_section.dart';
import 'package:doc_manager/widgets/metadata_section.dart';
import 'package:doc_manager/widgets/document_actions.dart';
import 'package:doc_manager/shared/components/responsive_builder.dart';
import 'package:doc_manager/screens/permissions_screen.dart';
import 'package:doc_manager/screens/shareable_links_screen.dart';
import 'dart:convert' show utf8;
import 'package:csv/csv.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kIsWeb;

// Add these to check if we're on Windows platform
import 'dart:io' show Platform;

class DocumentDetailScreen extends StatefulWidget {
  final Document document;
  final bool isEditing;
  final bool isNewDocument;
  
  const DocumentDetailScreen({
    super.key,
    required this.document,
    this.isEditing = false,
    this.isNewDocument = false,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _contentController = TextEditingController();
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isLoadingContent = false;
  String? _errorMessage;
  Document? _currentDocument;
  File? _localFile; // Track local file for document viewing
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isEditing = widget.isEditing;
    _nameController.text = widget.document.name;
    _currentDocument = widget.document;
    
    // For new documents, we're already in editing mode with empty content
    if (widget.isNewDocument) {
      _contentController.text = widget.document.content ?? '';
    } else {
      // Load document content if available
      _loadDocumentContent();
    }
    
    // Load versions and comments only for existing documents
    if (!widget.isNewDocument) {
      _loadData();
    }
  }
  
  Future<void> _loadDocumentContent() async {
    setState(() {
      _isLoadingContent = true;
      _errorMessage = null;
    });

    try {
      // First try to load directly from the document content if available
      if (widget.document.content != null && widget.document.content!.isNotEmpty) {
        setState(() {
          _contentController.text = widget.document.content!;
          _isLoadingContent = false;
        });
        return;
      }
      
      // Next try to load from file path if available
      if (widget.document.filePath != null && widget.document.filePath!.isNotEmpty) {
        try {
          developer.log('Attempting to load content from: ${widget.document.filePath}', name: 'DocumentDetailScreen');
          
          String filePath = widget.document.filePath!;
          
          // For file paths on the local system
          if (!filePath.startsWith('http://') && !filePath.startsWith('https://')) {
            try {
              // Create a local copy of the file for viewing
              await _createLocalCopyOfFile(filePath);
              
              // Try to read content for editable views
              if (_localFile != null && _localFile!.existsSync()) {
                try {
                  final fileContent = await _localFile!.readAsString();
                  setState(() {
                    _contentController.text = fileContent;
                    _isLoadingContent = false;
                  });
                  return;
                } catch (e) {
                  // Binary content that can't be read as text
                  developer.log('Could not read file as text: $e', name: 'DocumentDetailScreen');
                  setState(() {
                    _contentController.text = '[This document contains binary content that can only be viewed in the appropriate viewer.]';
                    _isLoadingContent = false;
                  });
                  return;
                }
              }
            } catch (e) {
              developer.log('Error creating local copy of file: $e', name: 'DocumentDetailScreen');
            }
          } else {
            // For network files
            try {
              final uri = Uri.parse(filePath);
              final response = await http.get(uri);
              
              if (response.statusCode == 200) {
                // Save the content to a local file for viewing
                final tempDir = await getTemporaryDirectory();
                final fileName = p.basename(uri.path);
                _localFile = File('${tempDir.path}/$fileName');
                await _localFile!.writeAsBytes(response.bodyBytes);
                
                // Try to set content if it's a text file
                try {
                  _contentController.text = utf8.decode(response.bodyBytes);
                } catch (e) {
                  _contentController.text = '[This document contains binary content that can only be viewed in the appropriate viewer.]';
                }
                
                setState(() {
                  _isLoadingContent = false;
                });
                return;
              }
            } catch (e) {
              developer.log('Error fetching network file: $e', name: 'DocumentDetailScreen');
            }
          }
        } catch (e) {
          developer.log('Error fetching file content: $e', name: 'DocumentDetailScreen');
        }
      }

      // Finally, fallback to loading the full document through the document bloc
      if (!widget.isNewDocument) {
        developer.log('Loading document through bloc: ${widget.document.id}', name: 'DocumentDetailScreen');
        context.read<DocumentBloc>().add(LoadDocument(widget.document.id));
      } else {
        setState(() {
          _isLoadingContent = false;
        });
      }
    } catch (e) {
      developer.log('Error loading document content: $e', name: 'DocumentDetailScreen');
      setState(() {
        _isLoadingContent = false;
        _errorMessage = 'Failed to load document content: $e';
      });
    }
  }
  
  // Helper method to create a local copy of a file for viewing
  Future<void> _createLocalCopyOfFile(String originalPath) async {
    try {
      developer.log('Creating local copy of file: $originalPath', name: 'DocumentDetailScreen');
      
      // Normalize path for Windows if needed
      String normalizedPath = originalPath;
      if (!kIsWeb && Platform.isWindows) {
        // Only replace backslashes if they exist
        if (normalizedPath.contains('\\')) {
          normalizedPath = normalizedPath.replaceAll('\\', '/');
          developer.log('Normalized Windows path: $normalizedPath', name: 'DocumentDetailScreen');
        }
      }
      
      // Create source file object
      final sourceFile = File(normalizedPath);
      
      // Check if file exists
      if (!sourceFile.existsSync()) {
        developer.log('Source file does not exist: $normalizedPath', name: 'DocumentDetailScreen');
        
        // Try alternative path formats for Windows
        if (!kIsWeb && Platform.isWindows) {
          // Try the original path without normalization
          final originalFile = File(originalPath);
          if (originalFile.existsSync()) {
            developer.log('Found file using original path: $originalPath', name: 'DocumentDetailScreen');
            
            // Create temp directory to store a copy
            final tempDir = await getTemporaryDirectory();
            final fileName = p.basename(originalPath);
            final targetPath = '${tempDir.path}/$fileName';
            
            // Create the target file
            _localFile = File(targetPath);
            
            // Copy the file content
            await _localFile!.writeAsBytes(await originalFile.readAsBytes());
            developer.log('Created local copy of file at: $targetPath', name: 'DocumentDetailScreen');
            return;
          }
        }
        
        throw Exception('Source file not found at path: $normalizedPath');
      }
      
      // Create temp directory to store a copy
      final tempDir = await getTemporaryDirectory();
      final fileName = p.basename(normalizedPath);
      final targetPath = '${tempDir.path}/$fileName';
      
      // Create the target file
      _localFile = File(targetPath);
      
      // Copy the file content
      await _localFile!.writeAsBytes(await sourceFile.readAsBytes());
      
      developer.log('Created local copy of file at: $targetPath', name: 'DocumentDetailScreen');
    } catch (e) {
      developer.log('Error creating local copy of file: $e', name: 'DocumentDetailScreen');
      _localFile = null;
      rethrow;
    }
  }
  
  void _loadData() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Safely load versions and comments with error handling
      context.read<VersionBloc>().add(LoadVersions(widget.document.id));
      context.read<CommentBloc>().add(GetComments(documentId: widget.document.id));
    } catch (e) {
      developer.log('Error loading document data: $e', name: 'DocumentDetailScreen');
      setState(() {
        _errorMessage = 'Failed to load document details: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    return BlocListener<DocumentBloc, DocumentState>(
      listener: (context, state) {
        if (state is DocumentError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Document Error: ${state.error}')),
          );
        } else if (state is DocumentOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is DocumentLoaded) {
          setState(() {
            _currentDocument = state.document;
            _contentController.text = state.document.content ?? '';
            _isLoadingContent = false;
            
            // Try to create local copy if we have a file path
            if (state.document.filePath != null && state.document.filePath!.isNotEmpty) {
              _createLocalCopyOfFile(state.document.filePath!)
                  .catchError((e) {
                developer.log('Error creating local copy after load: $e', name: 'DocumentDetailScreen');
              });
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: Text(
            _isEditing ? 'Edit Document' : (_currentDocument?.name ?? 'Document'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          actions: [
            if (!_isEditing) IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'permissions') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PermissionsScreen(documentId: widget.document.id),
                    ),
                  );
                } else if (value == 'share') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShareableLinksScreen(documentId: widget.document.id),
                    ),
                  );
                } else if (value == 'download') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download functionality will be implemented later')),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'permissions',
                  child: Text('Manage Permissions'),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Text('Shareable Links'),
                ),
                const PopupMenuItem(
                  value: 'download',
                  child: Text('Download Document'),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Document'),
              Tab(text: 'Versions'),
              Tab(text: 'Comments'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        body: _isLoading || _isLoadingContent
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDocumentTab(),
                _buildVersionsTab(),
                _buildCommentsTab(),
              ],
            ),
        bottomNavigationBar: _isEditing
            ? BottomAppBar(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _nameController.text = _currentDocument?.name ?? '';
                            _contentController.text = _currentDocument?.content ?? '';
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: _saveDocument,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
  
  Widget _buildDocumentTab() {
    return ResponsiveBuilder(
      mobile: _buildMobileDocumentView(),
      tablet: _buildTabletDocumentView(),
      desktop: _buildDesktopDocumentView(),
    );
  }
  
  Widget _buildMobileDocumentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEditing) ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Document Name',
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            _buildDocumentEditor(),
          ] else ...[
            Text(
              widget.document.name,
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Created: ${widget.document.createdAt.toString().split('.')[0]}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (widget.document.updatedAt != null)
              Text(
                'Last Modified: ${widget.document.updatedAt.toString().split('.')[0]}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildDocumentViewer(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTabletDocumentView() {
    return _buildMobileDocumentView(); // Similar layout with different padding
  }
  
  Widget _buildDesktopDocumentView() {
    return Center(
      child: SizedBox(
        width: 800,
        child: _buildMobileDocumentView(),
      ),
    );
  }
  
  Widget _buildVersionsTab() {
    return BlocConsumer<VersionBloc, VersionState>(
      listener: (context, state) {
        if (state is VersionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.error}')),
          );
        }
      },
      builder: (context, state) {
        if (state is VersionLoading || state is VersionsLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is VersionsLoaded) {
          final versions = state.versions;
          if (versions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No versions found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Versions will appear here when you make changes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: () {
                      context.read<VersionBloc>().add(LoadVersions(widget.document.id));
                    },
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: versions.length,
            itemBuilder: (context, index) {
              final version = versions[index];
              return ListTile(
                title: Text('Version ${version.versionNumber}'),
                subtitle: Text('Created: ${version.createdAt.toString().split('.')[0]}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      onPressed: () {
                        _showVersionPreviewDialog(version);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.restore),
                      onPressed: () {
                        _confirmRestoreVersion(version);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        } else if (state is VersionError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text('Error: ${state.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<VersionBloc>().add(LoadVersions(widget.document.id));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        return const Center(child: Text('Select a document to view versions'));
      },
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
  
  Widget _buildCommentsTab() {
    return Column(
      children: [
        Expanded(
          child: BlocConsumer<CommentBloc, CommentState>(
            listener: (context, state) {
              if (state is CommentError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${state.error}')),
                );
              }
            },
            builder: (context, state) {
              if (state is CommentLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is CommentsLoaded) {
                final comments = state.comments;
                if (comments.isEmpty) {
                  return const Center(child: Text('No comments found'));
                }
                
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(comment.content),
                      subtitle: Text(
                        'By ${comment.userId} on ${comment.createdAt.toString().split('.')[0]}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _confirmDeleteComment(comment);
                        },
                      ),
                    );
                  },
                );
              } else if (state is CommentError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${state.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<CommentBloc>().add(GetComments(documentId: widget.document.id));
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              
              return const Center(child: Text('Select a document to view comments'));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  if (_commentController.text.isNotEmpty) {
                    context.read<CommentBloc>().add(
                      CreateComment(
                        documentId: widget.document.id,
                        content: _commentController.text,
                      ),
                    );
                    _commentController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _showVersionPreviewDialog(Version version) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Version ${version.versionNumber}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Created: ${version.createdAt.toString().split('.')[0]}'),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(version.content ?? 'No content'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _confirmRestoreVersion(Version version) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Version'),
        content: Text('Are you sure you want to restore to version ${version.versionNumber}?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<DocumentBloc>().add(
                RestoreVersion(
                  documentId: widget.document.id,
                  versionId: version.id,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
  
  void _confirmDeleteComment(Comment comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
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
              context.read<CommentBloc>().add(DeleteComment(comment.id));
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  void _saveDocument() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document name cannot be empty')),
      );
      return;
    }

    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document content cannot be empty')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    // For new documents, we create a new document
    if (widget.isNewDocument) {
      context.read<DocumentBloc>().add(
        CreateDocument(
          name: _nameController.text,
          folderId: widget.document.folderId,
          content: _contentController.text,
        ),
      );
      
      // Close the screen and return to the document list
      Navigator.pop(context);
    } else {
      // For existing documents, we update the document
      context.read<DocumentBloc>().add(
        UpdateDocument(
          id: widget.document.id,
          folderId: widget.document.folderId,
          name: _nameController.text,
          content: _contentController.text,
        ),
      );
      
      setState(() {
        _isEditing = false;
      });
    }
  }
  
  Widget _buildDocumentEditor() {
    // Choose editor based on document type
    switch (_currentDocument?.type ?? widget.document.type) {
      case DocumentType.csv:
        return TextField(
          controller: _contentController,
          decoration: InputDecoration(
            labelText: 'CSV Content',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            helperText: 'Enter CSV data with comma-separated values',
            helperStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          ),
          maxLines: 20,
          minLines: 10,
          style: TextStyle(
            fontFamily: 'Courier', 
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          autofocus: false,
        );
      case DocumentType.docx:
        return TextField(
          controller: _contentController,
          decoration: InputDecoration(
            labelText: 'Document Content',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          maxLines: 20,
          minLines: 10,
          style: TextStyle(
            fontFamily: 'Arial', 
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          autofocus: false,
        );
      case DocumentType.pdf:
      default:
        return TextField(
          controller: _contentController,
          decoration: InputDecoration(
            labelText: 'Document Content',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            helperText: 'This content will be converted to PDF format',
            helperStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          ),
          maxLines: 20,
          minLines: 10,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          autofocus: false,
        );
    }
  }

  Widget _buildDocumentViewer() {
    // Choose viewer based on document type
    switch (_currentDocument?.type ?? widget.document.type) {
      case DocumentType.csv:
        return _buildCsvViewer();
      case DocumentType.docx:
        return _buildDocxViewer();
      case DocumentType.pdf:
        return _buildPdfViewer();
      default:
        return _buildDefaultViewer();
    }
  }

  Widget _buildCsvViewer() {
    if (_localFile == null || !_localFile!.existsSync()) {
      return Center(
        child: Text(
          'No CSV file available',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      );
    }

    return FutureBuilder<List<List<dynamic>>>(
      future: _parseCsvWithExcel(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          developer.log('Error parsing CSV: ${snapshot.error}', name: 'DocumentDetailScreen');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'Error parsing CSV file: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  onPressed: () => setState(() {}),
                ),
              ],
            ),
          );
        } else if (snapshot.hasData) {
          final data = snapshot.data!;
          if (data.isEmpty) {
            return const Center(
              child: Text('CSV file is empty'),
            );
          }

          return Column(
            children: [
              if (_currentDocument?.filePath != null)
                _buildFileHeader(),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 16,
                      headingRowColor: MaterialStateProperty.all(
                        Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                      ),
                      border: TableBorder.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                      columns: data.isNotEmpty
                          ? List.generate(
                              data[0].length,
                              (index) => DataColumn(
                                label: Text(
                                  data[0][index]?.toString() ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            )
                          : [],
                      rows: data.length > 1
                          ? List.generate(
                              data.length - 1,
                              (rowIndex) => DataRow(
                                cells: List.generate(
                                  data[0].length,
                                  (colIndex) => DataCell(
                                    Text(
                                      data[rowIndex + 1][colIndex]?.toString() ?? '',
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : [],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit CSV'),
                    onPressed: () {
                      _showCsvEditDialog(data);
                    },
                  ),
                ],
              ),
            ],
          );
        } else {
          return const Center(child: Text('No data available'));
        }
      },
    );
  }

  Future<List<List<dynamic>>> _parseCsvWithExcel() async {
    try {
      developer.log('Parsing CSV file with Excel 4.0.6: ${_localFile!.path}', name: 'DocumentDetailScreen');
      
      final bytes = await _localFile!.readAsBytes();
      
      // Use Excel package to parse the file
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        return [['No data found in CSV file']];
      }
      
      // Get the first sheet
      final sheet = excel.tables.keys.first;
      final table = excel.tables[sheet]!;
      
      final List<List<dynamic>> result = [];
      
      // Convert Excel rows to list format
      for (var rowIndex = 0; rowIndex < table.maxRows; rowIndex++) {
        final rowData = <dynamic>[];
        
        // Get the number of columns in this row
        int colCount = 0;
        for (var cell in table.rows[rowIndex]) {
          if (cell != null) colCount++;
        }
        
        for (var colIndex = 0; colIndex < colCount; colIndex++) {
          final cell = table.cell(CellIndex.indexByColumnRow(
            columnIndex: colIndex, 
            rowIndex: rowIndex
          ));
          
          rowData.add(cell.value);
        }
        result.add(rowData);
      }
      
      developer.log('CSV parsed successfully. Rows: ${result.length}, Columns: ${result.isNotEmpty ? result[0].length : 0}', 
               name: 'DocumentDetailScreen');
      return result;
    } catch (e) {
      developer.log('Error parsing CSV with Excel package: $e', name: 'DocumentDetailScreen');
      
      // Try fallback parsing method
      try {
        final content = await _localFile!.readAsString();
        final lines = content.split('\n');
        
        if (lines.isEmpty) {
          return [['CSV file is empty']];
        }
        
        final result = lines.where((line) => line.trim().isNotEmpty).map((line) {
          return line.split(',').map((cell) => cell.trim()).toList();
        }).toList();
        
        // If we don't have any data, create a default structure
        if (result.isEmpty) {
          return [['No data']];
        }
        
        developer.log('CSV parsed with fallback method. Rows: ${result.length}', name: 'DocumentDetailScreen');
        return result;
      } catch (fallbackError) {
        developer.log('Fallback CSV parsing failed: $fallbackError', name: 'DocumentDetailScreen');
        throw Exception('Failed to parse CSV: $e\nFallback parse error: $fallbackError');
      }
    }
  }

  void _showCsvEditDialog(List<List<dynamic>> data) {
    // Create a copy of data for editing
    final editableData = List<List<dynamic>>.from(
      data.map((row) => List<dynamic>.from(row))
    );
    
    // Create controllers for each cell
    final controllers = <List<TextEditingController>>[];
    for (final row in editableData) {
      final rowControllers = <TextEditingController>[];
      for (final cell in row) {
        rowControllers.add(TextEditingController(text: cell?.toString() ?? ''));
      }
      controllers.add(rowControllers);
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit CSV Data'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columnSpacing: 8.0,
                      headingRowHeight: 40,
                      dataRowHeight: 40,
                      border: TableBorder.all(
                        color: Colors.grey.shade300,
                      ),
                      columns: List.generate(
                        editableData[0].length,
                        (colIndex) => DataColumn(
                          label: Text('Col ${colIndex + 1}'),
                        ),
                      ),
                      rows: List.generate(
                        editableData.length,
                        (rowIndex) => DataRow(
                          cells: List.generate(
                            editableData[0].length,
                            (colIndex) => DataCell(
                              TextField(
                                controller: controllers[rowIndex][colIndex],
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: (value) {
                                  editableData[rowIndex][colIndex] = value;
                                },
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Row'),
                    onPressed: () {
                      setState(() {
                        Navigator.pop(context);
                        
                        // Add a new row and show the dialog again
                        final newRow = List<dynamic>.filled(editableData[0].length, '');
                        editableData.add(newRow);
                        _showCsvEditDialog(editableData);
                      });
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Row'),
                    onPressed: editableData.length > 1 ? () {
                      setState(() {
                        Navigator.pop(context);
                        
                        // Remove the last row and show the dialog again
                        editableData.removeLast();
                        _showCsvEditDialog(editableData);
                      });
                    } : null,
                  ),
                ],
              ),
            ],
          ),
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
              Navigator.pop(context);
              
              // Update data from controllers
              for (int i = 0; i < editableData.length; i++) {
                for (int j = 0; j < editableData[i].length; j++) {
                  editableData[i][j] = controllers[i][j].text;
                }
              }
              
              // Save the edited data
              _saveCsvData(editableData);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCsvData(List<List<dynamic>> data) async {
    try {
      // Create Excel object
      final excel = Excel.createExcel();
      
      // Get the default sheet
      final sheet = excel.sheets[excel.getDefaultSheet()];
      if (sheet == null) {
        throw Exception('Failed to get default sheet');
      }
      
      // Add data to sheet
      for (int row = 0; row < data.length; row++) {
        for (int col = 0; col < data[row].length; col++) {
          sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: row,
          )).value = data[row][col];
        }
      }
      
      // Save to bytes
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel document');
      }
      
      // Save to file
      await _localFile!.writeAsBytes(bytes);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV data saved successfully')),
      );
      
      // Refresh the view
      setState(() {});
      
    } catch (e) {
      developer.log('Error saving CSV data: $e', name: 'DocumentDetailScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save CSV data: $e')),
      );
    }
  }

  Widget _buildDocxViewer() {
    if (_contentController.text.isEmpty && _localFile == null) {
      return Center(
        child: Text(
          'No document content available',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      );
    } else if (_contentController.text.startsWith('[This document contains binary content') || _localFile != null) {
      // Try to view the binary DOCX file
      return FutureBuilder<List<String>>(
        future: _extractDocxContent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            developer.log('Error extracting DOCX content: ${snapshot.error}', name: 'DocumentDetailScreen');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Error displaying DOCX content: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    onPressed: () {
                      setState(() {});
                    },
                  ),
                ],
              )
            );
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentDocument?.filePath != null)
                    _buildFileHeader(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: snapshot.data!.map((paragraph) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            paragraph,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_document),
                    label: const Text('Edit Document'),
                    onPressed: () {
                      _showDocxEditOptions();
                    },
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.description, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not extract content from DOCX file',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_document),
                    label: const Text('Edit Document'),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                  ),
                ],
              ),
            );
          }
        },
      );
    } else {
      // Display the text content
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentDocument?.filePath != null)
              _buildFileHeader(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                _contentController.text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showDocxEditOptions() {
    final TextEditingController textController = TextEditingController();
    textController.text = _contentController.text;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Document Content'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: 'Enter document content',
              border: OutlineInputBorder(),
            ),
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final content = textController.text;
              Navigator.pop(context);
              await _saveDocxContent(content);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDocxContent(String content) async {
    try {
      if (_localFile == null) {
        // Create a new DOCX file if one doesn't exist
        final tempDir = await getTemporaryDirectory();
        final String fileName = '${tempDir.path}/document_${DateTime.now().millisecondsSinceEpoch}.docx';
        _localFile = File(fileName);
      }
      
      // Create a DocX template
      final docxBytes = await _getEmptyDocxTemplate();
      final docx = await DocxTemplate.fromBytes(docxBytes);
      
      // Create content object for the template
      final docContent = Content();
      docContent.add(TextContent("content", content));
      
      // Generate the document
      final bytes = await docx.generate(docContent);
      if (bytes == null) {
        throw Exception('Failed to generate DOCX document');
      }
      
      // Save the document
      await _localFile!.writeAsBytes(bytes);
      
      // Update the text controller
      _contentController.text = content;
      
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document saved successfully')),
      );
    } catch (e) {
      developer.log('Error saving DOCX content: $e', name: 'DocumentDetailScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save document: $e')),
      );
    }
  }

  // Helper method to get an empty DOCX template
  Future<List<int>> _getEmptyDocxTemplate() async {
    // This is a minimal valid DOCX file template
    // In a real app, you would use a properly formatted template file
    // For this example, we'll use a real template file bundled with the app or created programmatically
    
    try {
      // Check if we have an existing file to use as template
      if (_localFile != null && _localFile!.existsSync()) {
        return await _localFile!.readAsBytes();
      }
      
      // Create a minimal template
      return await _createMinimalDocxTemplate();
    } catch (e) {
      developer.log('Error getting empty DOCX template: $e', name: 'DocumentDetailScreen');
      throw Exception('Failed to create DOCX template: $e');
    }
  }

  Future<List<int>> _createMinimalDocxTemplate() async {
    // In a real app, we would have an actual DOCX template
    // For this example, we'll create a basic minimal DOCX template in code
    
    try {
      // Create a minimal in-memory DOCX file
      // This is a very simplified binary representation
      // In a real app, you would use a proper template file
      
      // These bytes represent a minimal valid but empty DOCX file
      // This is just for testing purposes
      final List<int> minimalDocxBytes = [
        80, 75, 3, 4, 20, 0, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
        20, 0, 0, 0, 119, 111, 114, 100, 47, 100, 111, 99, 117, 109, 101, 110, 116, 46, 120, 109, 108, 
        60, 119, 58, 100, 111, 99, 117, 109, 101, 110, 116, 32, 120, 109, 108, 110, 115, 58, 119, 61, 
        34, 104, 116, 116, 112, 58, 47, 47, 115, 99, 104, 101, 109, 97, 115, 46, 111, 112, 101, 110, 120, 
        109, 108, 102, 111, 114, 109, 97, 116, 115, 46, 111, 114, 103, 47, 119, 111, 114, 100, 112, 114, 
        111, 99, 101, 115, 115, 105, 110, 103, 109, 108, 47, 50, 48, 48, 54, 47, 109, 97, 105, 110, 34, 
        62, 60, 119, 58, 98, 111, 100, 121, 62, 60, 119, 58, 112, 62, 123, 123, 99, 111, 110, 116, 101, 
        110, 116, 125, 125, 60, 47, 119, 58, 112, 62, 60, 47, 119, 58, 98, 111, 100, 121, 62, 60, 47, 
        119, 58, 100, 111, 99, 117, 109, 101, 110, 116, 62
      ];
      
      return minimalDocxBytes;
    } catch (e) {
      developer.log('Error creating minimal DOCX template: $e', name: 'DocumentDetailScreen');
      
      // Return absolute minimal bytes for a DOCX file (not valid, just placeholders)
      return [80, 75, 3, 4, 20, 0, 0, 0, 8, 0];
    }
  }

  // Helper method to extract content from DOCX file
  Future<List<String>> _extractDocxContent() async {
    if (_localFile == null || !_localFile!.existsSync()) {
      return ['No file available to extract content from.'];
    }
    
    try {
      // Try to parse the DOCX file
      final docxBytes = await _localFile!.readAsBytes();
      
      // Check if file is a valid DOCX by looking for the ZIP signature
      if (docxBytes.length < 4 || docxBytes[0] != 0x50 || docxBytes[1] != 0x4B) {
        return ['File does not appear to be a valid DOCX document.'];
      }
      
      try {
        developer.log('Trying to parse DOCX with docx_template...', name: 'DocumentDetailScreen');
        
        // Create a temporary file to save the docx content
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.docx');
        await tempFile.writeAsBytes(docxBytes);
        
        // Use docx_template to parse the document
        final docx = await DocxTemplate.fromBytes(docxBytes);
        
        final content = <String>[];
        
        // Get basic document info
        content.add("Microsoft Word Document");
        content.add("File: ${_localFile!.path}");
        content.add("Size: ${docxBytes.length} bytes");
        
        // Extract text from document (basic implementation)
        content.add("");
        content.add("Document Content:");
        content.add("------------------");
        
        // Try to extract any available tags
        try {
          final tags = docx.getTags();
          if (tags.isNotEmpty) {
            content.add("\nDocument tags found:");
            for (var tag in tags) {
              content.add("- $tag");
            }
          } else {
            content.add("No extractable content found in this document.");
          }
        } catch (e) {
          content.add("Could not extract content: $e");
        }
        
        // Clean up temporary file
        if (tempFile.existsSync()) {
          await tempFile.delete();
        }
        
        return content;
      } catch (e) {
        developer.log('Error parsing DOCX with docx_template: $e', name: 'DocumentDetailScreen');
        
        // Fallback to showing raw content structure
        return [
          'Document content could not be fully parsed.',
          'This is a Microsoft Word document.',
          '',
          'Document properties:',
          'Size: ${docxBytes.length} bytes',
          'File: ${_localFile!.path}',
          '',
          'You can edit this document using the Edit button.',
        ];
      }
    } catch (e) {
      developer.log('Error reading DOCX file: $e', name: 'DocumentDetailScreen');
      return ['Error extracting content: $e'];
    }
  }

  Widget _buildPdfViewer() {
    if (_localFile == null || !_localFile!.existsSync()) {
      return Center(
        child: Text(
          'No PDF file available',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      );
    }

    try {
      // Using SfPdfViewer for displaying PDF
      return Column(
        children: [
          if (_currentDocument?.filePath != null)
            _buildFileHeader(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SfPdfViewer.file(
                  _localFile!,
                  enableTextSelection: true,
                  pageLayoutMode: PdfPageLayoutMode.continuous,
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    developer.log('Error loading PDF: ${details.error}', name: 'DocumentDetailScreen');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to load PDF: ${details.description}')),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_document),
                label: const Text('Edit PDF'),
                onPressed: () {
                  _showPdfEditOptions();
                },
              ),
            ],
          ),
        ],
      );
    } catch (e) {
      developer.log('Error in PDF viewer: $e', name: 'DocumentDetailScreen');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error displaying PDF: $e',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: () {
                setState(() {});
              },
            ),
          ],
        ),
      );
    }
  }

  void _showPdfEditOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PDF Edit Options',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text('Add Annotation'),
              onTap: () {
                Navigator.pop(context);
                _addAnnotationToPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Add Text'),
              onTap: () {
                Navigator.pop(context);
                _addTextToPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export Modified PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportModifiedPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  // New method to add annotation to PDF using syncfusion_flutter_pdf
  Future<void> _addAnnotationToPdf() async {
    try {
      if (_localFile == null || !_localFile!.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF file not available')),
        );
        return;
      }
      
      final bytes = await _localFile!.readAsBytes();
      
      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      // Get the first page
      final PdfPage page = document.pages[0];
      
      // Add a rectangle annotation
      final PdfRectangleAnnotation rectangleAnnotation = PdfRectangleAnnotation(
        Rect.fromLTWH(0, 0, 100, 100),
        'Rectangle Annotation',
        author: 'Document Manager',
        subject: 'Rectangle',
        color: PdfColor(255, 0, 0),
      );
      
      // Add the annotation to the page
      page.annotations.add(rectangleAnnotation);
      
      // Save the modified document
      final List<int> modifiedBytes = await document.save();
      
      // Save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final String fileName = '${tempDir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final File file = File(fileName);
      await file.writeAsBytes(modifiedBytes);
      
      // Update local file reference
      setState(() {
        _localFile = file;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annotation added successfully')),
      );
      
      // Close the document to release resources
      document.dispose();
    } catch (e) {
      developer.log('Error adding annotation to PDF: $e', name: 'DocumentDetailScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add annotation: $e')),
      );
    }
  }

  // New method to add text to PDF using syncfusion_flutter_pdf
  Future<void> _addTextToPdf() async {
    try {
      if (_localFile == null || !_localFile!.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF file not available')),
        );
        return;
      }
      
      final bytes = await _localFile!.readAsBytes();
      
      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      // Get the first page
      final PdfPage page = document.pages[0];
      
      // Create a new PDF font
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      
      // Create a PDF graphics object for drawing on the page
      final PdfGraphics graphics = page.graphics;
      
      // Draw text on the page
      graphics.drawString(
        'Text added on ${DateTime.now().toString()}',
        font,
        brush: PdfSolidBrush(PdfColor(0, 0, 255)),
        bounds: const Rect.fromLTWH(0, 0, 300, 50),
      );
      
      // Save the modified document
      final List<int> modifiedBytes = await document.save();
      
      // Save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final String fileName = '${tempDir.path}/text_added_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final File file = File(fileName);
      await file.writeAsBytes(modifiedBytes);
      
      // Update local file reference
      setState(() {
        _localFile = file;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text added successfully')),
      );
      
      // Close the document to release resources
      document.dispose();
    } catch (e) {
      developer.log('Error adding text to PDF: $e', name: 'DocumentDetailScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add text: $e')),
      );
    }
  }

  // New method to export the modified PDF
  Future<void> _exportModifiedPdf() async {
    try {
      if (_localFile == null || !_localFile!.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF file not available')),
        );
        return;
      }
      
      // Share the file
      await Share.shareXFiles(
        [XFile(_localFile!.path)],
        text: 'Sharing modified PDF document',
      );
    } catch (e) {
      developer.log('Error exporting PDF: $e', name: 'DocumentDetailScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    }
  }

  Widget _buildDefaultViewer() {
    if (_contentController.text.isEmpty) {
      return Center(
        child: Text(
          'No document content available',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      );
    } else if (_contentController.text.startsWith('[This document contains binary content')) {
      return _buildBinaryFileViewer();
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentDocument?.filePath != null)
              _buildFileHeader(),
            Text(
              _contentController.text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBinaryFileViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Binary file content cannot be displayed directly',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
          const SizedBox(height: 24),
          if (_localFile != null && _localFile!.existsSync())
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Document'),
              onPressed: () {
                // Use the appropriate viewer based on document type
                if (_currentDocument?.type == DocumentType.pdf) {
                  setState(() {
                    // This forces a rebuild to use the PDF viewer
                    _tabController.animateTo(0);
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This document type requires an external viewer')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFileHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'File: ${_currentDocument!.name}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download'),
            onPressed: () {
              // This would be implemented with a proper file download mechanism
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download functionality will be implemented later')),
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Helper method to try alternative ways to load a PDF when primary method fails
  void _tryAlternativePdfLoading() {
    try {
      // If we have a document ID, try to fetch the document again
      if (_currentDocument != null && _currentDocument!.id.isNotEmpty) {
        developer.log('Trying to reload document: ${_currentDocument!.id}', name: 'DocumentDetailScreen');
        context.read<DocumentBloc>().add(LoadDocument(_currentDocument!.id));
      }
    } catch (e) {
      developer.log('Error in alternative PDF loading: $e', name: 'DocumentDetailScreen');
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _contentController.dispose();
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }
} 
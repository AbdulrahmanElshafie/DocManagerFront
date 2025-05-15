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
  final String? initialTemplate;
  
  const DocumentDetailScreen({
    super.key,
    required this.document,
    this.isEditing = false,
    this.isNewDocument = false,
    this.initialTemplate,
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
      // Check if we need to apply a template
      if (widget.initialTemplate != null) {
        _applyTemplate(widget.initialTemplate!);
      } else {
      _contentController.text = widget.document.content ?? '';
      }
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
        developer.log('Document content loaded from document.content', name: 'DocumentDetailScreen');
        return;
      }
      
      // Next try to load from file path if available
      if (widget.document.filePath != null && widget.document.filePath!.isNotEmpty) {
        try {
          developer.log('Attempting to load content from path: ${widget.document.filePath}', name: 'DocumentDetailScreen');
          
          String filePath = widget.document.filePath!;
          
              // Create a local copy of the file for viewing
          File? file = await _createLocalCopyOfFile(filePath);
          
          if (file != null && file.existsSync()) {
            developer.log('Successfully created local file at: ${file.path}', name: 'DocumentDetailScreen');
            _localFile = file;
            
            // Based on document type, call the appropriate loader
            switch (widget.document.type) {
              case DocumentType.csv:
                await _loadCsvContent(file.path);
                break;
              case DocumentType.docx:
                await _loadDocxContent(file.path);
                break;
              case DocumentType.pdf:
                await _loadPdfContent(file.path);
                break;
              default:
                await _loadGenericContent(file.path);
            }
          } else {
            developer.log('Failed to create local copy of file', name: 'DocumentDetailScreen');
            throw Exception('Failed to create local copy of file');
                }
                
                setState(() {
                  _isLoadingContent = false;
                });
                return;
            } catch (e) {
          developer.log('Error loading file content: $e', name: 'DocumentDetailScreen');
          // We'll continue to try loading through the document bloc
        }
      } else {
        developer.log('No file path available in document', name: 'DocumentDetailScreen');
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
  Future<File?> _createLocalCopyOfFile(String originalPath) async {
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
      File? localFile;
      
      // First attempt: try with normalized path
      if (sourceFile.existsSync()) {
        // Create temp directory to store a copy
        final tempDir = await getTemporaryDirectory();
        final fileName = p.basename(normalizedPath);
        final targetPath = '${tempDir.path}/$fileName';
        
        // Create the target file
        localFile = File(targetPath);
        
        // Copy the file content
        await localFile.writeAsBytes(await sourceFile.readAsBytes());
        
        developer.log('Created local copy of file at: $targetPath from normalized path', name: 'DocumentDetailScreen');
        _localFile = localFile;
        return localFile;
      }
      
      // Second attempt: Try with original path
          final originalFile = File(originalPath);
          if (originalFile.existsSync()) {
            developer.log('Found file using original path: $originalPath', name: 'DocumentDetailScreen');
            
            // Create temp directory to store a copy
            final tempDir = await getTemporaryDirectory();
            final fileName = p.basename(originalPath);
            final targetPath = '${tempDir.path}/$fileName';
            
            // Create the target file
        localFile = File(targetPath);
            
            // Copy the file content
        await localFile.writeAsBytes(await originalFile.readAsBytes());
        developer.log('Created local copy of file at: $targetPath from original path', name: 'DocumentDetailScreen');
        _localFile = localFile;
        return localFile;
      }
      
      // Third attempt: Handle the case where the path is a network location or relative path
      try {
        // Try to download from URL if path looks like a URL
        if (originalPath.startsWith('http://') || originalPath.startsWith('https://')) {
          developer.log('Trying to download from URL: $originalPath', name: 'DocumentDetailScreen');
          final response = await http.get(Uri.parse(originalPath));
          
          if (response.statusCode == 200) {
      final tempDir = await getTemporaryDirectory();
            final fileName = originalPath.split('/').last;
      final targetPath = '${tempDir.path}/$fileName';
      
      // Create the target file
            localFile = File(targetPath);
            
            // Write the downloaded bytes
            await localFile.writeAsBytes(response.bodyBytes);
            developer.log('Downloaded and saved file from URL: $targetPath', name: 'DocumentDetailScreen');
            _localFile = localFile;
            return localFile;
          } else {
            throw Exception('Failed to download file: HTTP ${response.statusCode}');
          }
        }
      } catch (e) {
        developer.log('Failed URL download attempt: $e', name: 'DocumentDetailScreen');
        // Continue to next attempt
      }
      
      // If we reach here, we couldn't find the file
      developer.log('Source file not found at path: $normalizedPath or $originalPath', name: 'DocumentDetailScreen');
      throw Exception('Source file not found');
    } catch (e) {
      developer.log('Error creating local copy of file: $e', name: 'DocumentDetailScreen');
      return null;
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
          // Store document first to avoid race conditions
            _currentDocument = state.document;
            _contentController.text = state.document.content ?? '';
            
          // File path handling
            if (state.document.filePath != null && state.document.filePath!.isNotEmpty) {
            // Keep loading state active during file copy
            _isLoadingContent = true;
            
            // Use async/await properly
              _createLocalCopyOfFile(state.document.filePath!)
              .then((file) {
                // Only update state when file copy completes
                setState(() {
                  _isLoadingContent = false;
                });
              })
                  .catchError((e) {
                developer.log('Error creating local copy after load: $e', name: 'DocumentDetailScreen');
                setState(() {
                  _isLoadingContent = false;
                });
              });
          } else {
            // No file path, just update state
            setState(() {
              _isLoadingContent = false;
            });
          }
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CSV Editor',
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            TextField(
          controller: _contentController,
          decoration: InputDecoration(
            labelText: 'CSV Content',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
                helperText: 'Enter CSV data with comma-separated values (each line is a row)',
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
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.table_chart),
              label: const Text('Edit as Table'),
              onPressed: () => _showCsvStructuredEditor(),
            ),
          ],
        );
      case DocumentType.docx:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DOCX Editor',
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            TextField(
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
            ),
          ],
        );
      case DocumentType.pdf:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PDF Content Editor',
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            TextField(
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
            ),
          ],
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
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'This file type is not supported',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildCsvViewer() {
    if (_localFile == null) {
      developer.log('No _localFile set for CSV viewing', name: 'DocumentDetailScreen');
      
      // Try to reload document content if we have a file path
      if (_currentDocument?.filePath != null && _currentDocument!.filePath!.isNotEmpty) {
        return FutureBuilder<File?>(
          future: _createLocalCopyOfFile(_currentDocument!.filePath!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return _buildErrorDisplay('Error loading CSV file: ${snapshot.error}');
            } else if (snapshot.hasData && snapshot.data != null) {
              final file = snapshot.data!;
              if (file.existsSync()) {
                return _buildActualCsvViewer(file);
              } else {
                return _buildErrorDisplay('CSV file not found');
              }
            } else {
              return _buildErrorDisplay('Could not load CSV file');
            }
          },
        );
      }
      
      return _buildErrorDisplay('No CSV file available');
    }
    
    if (!_localFile!.existsSync()) {
      developer.log('_localFile exists but file does not exist: ${_localFile!.path}', name: 'DocumentDetailScreen');
      return _buildErrorDisplay('CSV file not found at: ${_localFile!.path}');
    }

    return _buildActualCsvViewer(_localFile!);
  }

  Widget _buildActualCsvViewer(File file) {
    return FutureBuilder<List<List<dynamic>>>(
      future: _parseCsvWithExcel(file),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          developer.log('Error parsing CSV: ${snapshot.error}', name: 'DocumentDetailScreen');
          return _buildErrorDisplay('Error parsing CSV file: ${snapshot.error}');
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

  Future<List<List<dynamic>>> _parseCsvWithExcel([File? file]) async {
    final targetFile = file ?? _localFile;
    
    if (targetFile == null || !targetFile.existsSync()) {
      return [['No CSV file available']];
    }
    
    try {
      developer.log('Parsing CSV file with Excel 4.0.6: ${targetFile.path}', name: 'DocumentDetailScreen');
      
      final bytes = await targetFile.readAsBytes();
      
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
        final content = await targetFile.readAsString();
        final lines = content.split('\n');
        
        if (lines.isEmpty) {
          return [['CSV file is empty']];
        }
        
        final result = lines.where((line) => line.trim().isNotEmpty).map((line) {
          return line.split(',').map((cell) => cell.trim()).toList();
        }).toList();
        
        developer.log('CSV parsed with fallback method. Rows: ${result.length}', name: 'DocumentDetailScreen');
        return result;
      } catch (e) {
        developer.log('Error parsing CSV with fallback method: $e', name: 'DocumentDetailScreen');
        return [['Error parsing CSV file: $e']];
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
      builder: (dialogContext) {
        // Variables within dialog scope
        int rowCount = editableData.length;
        int colCount = editableData.isEmpty ? 0 : editableData[0].length;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
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
                              colCount,
                        (colIndex) => DataColumn(
                          label: Text('Col ${colIndex + 1}'),
                        ),
                      ),
                      rows: List.generate(
                              rowCount,
                        (rowIndex) => DataRow(
                          cells: List.generate(
                                  colCount,
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
                            setDialogState(() {
                              // Add a new row to data model and controllers
                              final newRow = List<dynamic>.filled(colCount, '');
                        editableData.add(newRow);
                              
                              final newControllers = List<TextEditingController>.generate(
                                colCount,
                                (index) => TextEditingController(),
                              );
                              controllers.add(newControllers);
                              
                              rowCount = editableData.length;
                      });
                    },
                  ),
                  TextButton.icon(
                          icon: const Icon(Icons.add_box),
                          label: const Text('Add Column'),
                          onPressed: () {
                            setDialogState(() {
                              // Add a new column to all rows
                              for (final row in editableData) {
                                row.add('');
                              }
                              
                              // Add new controller for each row
                              for (final row in controllers) {
                                row.add(TextEditingController());
                              }
                              
                              colCount = editableData.isEmpty ? 1 : editableData[0].length;
                            });
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
                  onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Update data from controllers
              for (int i = 0; i < editableData.length; i++) {
                for (int j = 0; j < editableData[i].length; j++) {
                  editableData[i][j] = controllers[i][j].text;
                }
              }
              
              // Save the edited data
              _saveCsvData(editableData);
                    
                    Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
            );
          },
        );
      },
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
    if (_localFile == null) {
      developer.log('No _localFile set for DOCX viewing', name: 'DocumentDetailScreen');
      
      // Try to reload document content if we have a file path
      if (_currentDocument?.filePath != null && _currentDocument!.filePath!.isNotEmpty) {
        return FutureBuilder<File?>(
          future: _createLocalCopyOfFile(_currentDocument!.filePath!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
              return _buildErrorDisplay('Error loading DOCX file: ${snapshot.error}');
            } else if (snapshot.hasData && snapshot.data != null) {
              final file = snapshot.data!;
              if (file.existsSync()) {
                return _buildActualDocxViewer(file);
              } else {
                return _buildErrorDisplay('DOCX file not found');
              }
            } else {
              return _buildErrorDisplay('Could not load DOCX file');
            }
          },
        );
      }
      
      // If we have content in the controller, display that
      if (_contentController.text.isNotEmpty && !_contentController.text.startsWith('[This document contains binary')) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
      
      return _buildErrorDisplay('No DOCX file available');
    }
    
    if (!_localFile!.existsSync()) {
      developer.log('_localFile exists but file does not exist: ${_localFile!.path}', name: 'DocumentDetailScreen');
      return _buildErrorDisplay('DOCX file not found at: ${_localFile!.path}');
    }

    return _buildActualDocxViewer(_localFile!);
  }

  Widget _buildActualDocxViewer(File file) {
    // Try to view the binary DOCX file
    return FutureBuilder<List<String>>(
      future: _extractDocxContent(file),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          developer.log('Error extracting DOCX content: ${snapshot.error}', name: 'DocumentDetailScreen');
          return _buildErrorDisplay('Error displaying DOCX content: ${snapshot.error}');
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
  }

  Widget _buildPdfViewer() {
      if (_localFile == null) {
      developer.log('No _localFile set for PDF viewing', name: 'DocumentDetailScreen');
      
      // Try to reload document content if we have a file path
      if (_currentDocument?.filePath != null && _currentDocument!.filePath!.isNotEmpty) {
        return FutureBuilder<File?>(
          future: _createLocalCopyOfFile(_currentDocument!.filePath!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return _buildErrorDisplay('Error loading PDF file: ${snapshot.error}');
            } else if (snapshot.hasData && snapshot.data != null) {
              final file = snapshot.data!;
              if (file.existsSync()) {
                return _buildActualPdfViewer(file);
              } else {
                return _buildErrorDisplay('PDF file not found');
            }
          } else {
              return _buildErrorDisplay('Could not load PDF file');
            }
          },
        );
      }
      
      return _buildErrorDisplay('No PDF file available');
    }
    
    if (!_localFile!.existsSync()) {
      developer.log('_localFile exists but file does not exist: ${_localFile!.path}', name: 'DocumentDetailScreen');
      return _buildErrorDisplay('PDF file not found at: ${_localFile!.path}');
    }

    return _buildActualPdfViewer(_localFile!);
  }

  Widget _buildActualPdfViewer(File file) {
    try {
      developer.log('Displaying PDF from file: ${file.path}', name: 'DocumentDetailScreen');
      
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
                  file,
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
      return _buildErrorDisplay('Error displaying PDF: $e');
    }
  }
  
  Widget _buildErrorDisplay(String message) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
            message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
          if (!_isLoadingContent) // Only show retry button if not already loading
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: () {
                // Prevent multiple reloading attempts
                if (!_isLoadingContent) {
                  _loadDocumentContent();
                }
              },
            ),
          ],
        ),
      );
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
  
  // Method to show structured CSV editor with an Excel-like interface
  void _showCsvStructuredEditor() {
    try {
      // Parse current content into rows and columns
      final List<List<String>> csvData = [];
      
      // Split content by lines
      final lines = _contentController.text.split('\n');
      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          // Parse CSV line, handling quoted fields
          csvData.add(_parseCsvLine(line));
        }
      }
      
      // Ensure we have at least one row with one cell
      if (csvData.isEmpty) {
        csvData.add(['']);
      }
      
      // Calculate max columns for consistent table width
      int maxColumns = 0;
      for (final row in csvData) {
        if (row.length > maxColumns) {
          maxColumns = row.length;
        }
      }
      
      // Ensure maxColumns is at least 1
      maxColumns = maxColumns > 0 ? maxColumns : 1;
      
      // Normalize all rows to have same number of columns
      for (final row in csvData) {
        while (row.length < maxColumns) {
          row.add('');
        }
      }
      
      // Create controllers for each cell
      final controllers = <List<TextEditingController>>[];
      for (final row in csvData) {
        final rowControllers = <TextEditingController>[];
        for (final cell in row) {
          rowControllers.add(TextEditingController(text: cell));
        }
        controllers.add(rowControllers);
      }
      
      // Track current dimensions with state variables inside the dialog
      showDialog(
        context: context,
        builder: (dialogContext) {
          // These variables will be managed by the StatefulBuilder
          int rowCount = csvData.length;
          int colCount = maxColumns;
          
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('CSV Table Editor'),
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
                                colCount,
                                (index) => DataColumn(
                                  label: Text('Column ${index + 1}'),
                                ),
                              ),
                              rows: List.generate(
                                rowCount,
                                (rowIndex) => DataRow(
                                  cells: List.generate(
                                    colCount,
                                    (colIndex) => DataCell(
                                      TextField(
                                        controller: rowIndex < controllers.length && 
                                                 colIndex < controllers[rowIndex].length
                                            ? controllers[rowIndex][colIndex]
                                            : TextEditingController(),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                        onChanged: (value) {
                                          // Update the data model when text changes
                                          if (rowIndex < csvData.length && colIndex < csvData[rowIndex].length) {
                                            csvData[rowIndex][colIndex] = value;
                                          }
                                        },
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
                              setDialogState(() {
                                // Add a new row to data model and controllers
                                final newRow = List<String>.filled(colCount, '');
                                csvData.add(newRow);
                                
                                final newControllers = List<TextEditingController>.generate(
                                  colCount,
                                  (index) => TextEditingController(),
                                );
                                controllers.add(newControllers);
                                
                                // Update row count
                                rowCount = csvData.length;
                              });
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add_box),
                            label: const Text('Add Column'),
                            onPressed: () {
                              setDialogState(() {
                                // Add a new column to all rows
                                for (final row in csvData) {
                                  row.add('');
                                }
                                
                                // Add new controller for each row
                                for (final row in controllers) {
                                  row.add(TextEditingController());
                                }
                                
                                // Update column count
                                colCount = maxColumns + 1;
                                maxColumns = colCount;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Convert data back to CSV text
                      final StringBuffer buffer = StringBuffer();
                      
                      for (final row in csvData) {
                        final formattedRow = row.map((cell) {
                          // If cell contains comma, quote it
                          if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
                            return '"${cell.replaceAll('"', '""')}"';
                          }
                          return cell;
                        }).join(',');
                        
                        buffer.writeln(formattedRow);
                      }
                      
                      // Update the text controller with new CSV data
                      _contentController.text = buffer.toString();
                      
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      developer.log('Error in CSV structured editor: $e', name: 'DocumentDetailScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing CSV: $e')),
      );
    }
  }

  // Helper method to parse a CSV line, handling quoted fields
  List<String> _parseCsvLine(String line) {
    if (line.trim().isEmpty) {
      return [''];
    }
    
    try {
      final fields = <String>[];
      bool inQuotes = false;
      StringBuffer currentField = StringBuffer();
      
      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        
        if (char == '"') {
          // If we see a quote inside quotes, and the next char is also a quote, it's an escaped quote
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            currentField.write('"');
            i++; // Skip the next quote as we've handled it
          } else {
            // Toggle quote state
            inQuotes = !inQuotes;
          }
        } else if (char == ',' && !inQuotes) {
          // End of field
          fields.add(currentField.toString());
          currentField = StringBuffer();
        } else {
          currentField.write(char);
        }
      }
      
      // Add the last field
      fields.add(currentField.toString());
      return fields;
    } catch (e) {
      // Simple fallback - just split by commas
      return line.split(',');
    }
  }
  
  // Apply a template based on document type and template name
  void _applyTemplate(String templateName) {
    try {
      switch (_currentDocument?.type ?? widget.document.type) {
        case DocumentType.csv:
          _applyCsvTemplate(templateName);
          break;
        case DocumentType.docx:
          _applyDocxTemplate(templateName);
          break;
        case DocumentType.pdf:
          _applyPdfTemplate(templateName);
          break;
        default:
          // No template to apply for unknown types
          _contentController.text = '';
      }
    } catch (e) {
      developer.log('Error applying template: $e', name: 'DocumentDetailScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply template: $e')),
      );
      _contentController.text = '';
    }
  }
  
  // Apply CSV template
  void _applyCsvTemplate(String templateName) {
    final StringBuffer buffer = StringBuffer();
    
    switch (templateName) {
      case 'Contacts':
        buffer.writeln('Name,Email,Phone,Address,Company');
        buffer.writeln('John Doe,john@example.com,555-123-4567,"123 Main St, City",ACME Inc.');
        buffer.writeln('Jane Smith,jane@example.com,555-765-4321,"456 Oak Ave, Town",XYZ Corp');
        break;
      case 'Inventory':
        buffer.writeln('Item ID,Name,Category,Quantity,Price,Supplier');
        buffer.writeln('001,Laptop,Electronics,10,1200.00,Tech Supplies Inc.');
        buffer.writeln('002,Desk Chair,Furniture,15,250.00,Office Furniture Co.');
        buffer.writeln('003,Printer Paper,Office Supplies,100,5.99,Paper Plus Ltd.');
        break;
      case 'Financial':
        buffer.writeln('Date,Description,Category,Income,Expense,Balance');
        buffer.writeln('2023-01-01,Initial Balance,Setup,1000.00,0.00,1000.00');
        buffer.writeln('2023-01-15,Office Supplies,Expense,0.00,125.50,874.50');
        buffer.writeln('2023-01-20,Client Payment,Income,500.00,0.00,1374.50');
        break;
      default:
        // Blank template with example headers
        buffer.writeln('Column1,Column2,Column3');
        buffer.writeln('Value1,Value2,Value3');
    }
    
    _contentController.text = buffer.toString();
  }
  
  // Apply DOCX template
  void _applyDocxTemplate(String templateName) {
    switch (templateName) {
      case 'Letter':
        _contentController.text = '''[Your Name]
[Your Address]
[City, State ZIP]
[Your Email]
[Your Phone]

[Date]

[Recipient Name]
[Recipient Title]
[Company Name]
[Street Address]
[City, State ZIP]

Dear [Recipient Name],

I am writing to [state the purpose of your letter]. 

[Include relevant details in this paragraph. Be clear and concise about your main point.]

[In this paragraph, provide additional information or explain your request in more detail.]

[In the closing paragraph, thank the recipient and include any necessary follow-up information.]

Sincerely,

[Your Name]''';
        break;
      case 'Resume':
        _contentController.text = '''JOHN DOE
123 Main Street, City, State ZIP | (555) 123-4567 | john.doe@email.com | LinkedIn: linkedin.com/in/johndoe

PROFESSIONAL SUMMARY
Experienced [Your Profession] with [X years] of expertise in [key skill], [key skill], and [key skill]. Proven track record of [your notable achievement] and [another achievement].

SKILLS
• Technical: [Skill 1], [Skill 2], [Skill 3]
• Software: [Software 1], [Software 2], [Software 3]
• Languages: [Language 1], [Language 2]

EXPERIENCE
[COMPANY NAME], [Location] | [Start Date] - [End Date]
[Your Title]
• [Achievement or responsibility]
• [Achievement or responsibility]
• [Achievement or responsibility]

[PREVIOUS COMPANY], [Location] | [Start Date] - [End Date]
[Your Title]
• [Achievement or responsibility]
• [Achievement or responsibility]

EDUCATION
[UNIVERSITY NAME], [Location]
[Degree] in [Field of Study] | [Graduation Date]
• [Relevant coursework, honors, or activities]''';
        break;
      case 'Meeting Minutes':
        _contentController.text = '''MEETING MINUTES

Meeting Title: [Title]
Date: [Date]
Time: [Start Time] - [End Time]
Location: [Location]

Attendees:
- [Name], [Title]
- [Name], [Title]
- [Name], [Title]

Absent:
- [Name], [Title]

Agenda Items:
1. [Agenda Item 1]
2. [Agenda Item 2]
3. [Agenda Item 3]

Discussion:
1. [Agenda Item 1]
   • [Key discussion point]
   • [Key discussion point]
   • Decision: [Decision made]
   • Action: [Action item] - Assigned to: [Name], Due: [Date]

2. [Agenda Item 2]
   • [Key discussion point]
   • [Key discussion point]
   • Decision: [Decision made]
   • Action: [Action item] - Assigned to: [Name], Due: [Date]

Next Meeting:
Date: [Date]
Time: [Time]
Location: [Location]

Minutes submitted by: [Name]
Minutes approved by: [Name]''';
        break;
      default:
        // Blank template
        _contentController.text = 'Enter your document content here.';
    }
  }
  
  // Apply PDF template using syncfusion_flutter_pdf
  void _applyPdfTemplate(String templateName) async {
    try {
      // Initialize with placeholder text while we generate the PDF
      _contentController.text = 'Creating PDF template...';
      
      // Create a PDF document
      final PdfDocument document = PdfDocument();
      
      // Create a page
      final PdfPage page = document.pages.add();
      
      // Get graphics for drawing
      final PdfGraphics graphics = page.graphics;
      
      // Create a font
      final PdfFont headerFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
      final PdfFont normalFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
      
      PdfBrush brush = PdfSolidBrush(PdfColor(0, 0, 0));
      String content = '';
      
      switch (templateName) {
        case 'Business Letter':
          // Draw a business letter template
          graphics.drawString('BUSINESS LETTER', headerFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 0, 500, 40),
            format: PdfStringFormat(alignment: PdfTextAlignment.center)
          );
          
          graphics.drawString('Company Name', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
            brush: brush,
            bounds: const Rect.fromLTWH(0, 60, 500, 30)
          );
          
          graphics.drawString('123 Company Street, City, State ZIP\nPhone: (555) 123-4567\nEmail: info@company.com', normalFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 90, 500, 60)
          );
          
          graphics.drawLine(
            PdfPen(PdfColor(0, 0, 0)),
            Offset(0, 160),
            Offset(page.getClientSize().width, 160)
          );
          
          String letterContent = '''
          
[Date]

[Recipient Name]
[Recipient Company]
[Street Address]
[City, State ZIP]

Dear [Recipient],

[Body of the letter. Explain the purpose of your letter in clear, concise language. Add any necessary details to support your main point.]

[Additional paragraph if needed.]

Sincerely,

[Your Name]
[Your Title]
          ''';
          
          graphics.drawString(letterContent, normalFont,
            brush: brush,
            bounds: Rect.fromLTWH(0, 180, page.getClientSize().width, page.getClientSize().height - 180)
          );
          
          content = 'Business Letter template created';
          break;
          
        case 'Invoice':
          // Draw invoice template
          graphics.drawString('INVOICE', headerFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 0, 500, 40),
            format: PdfStringFormat(alignment: PdfTextAlignment.center)
          );
          
          graphics.drawString('Company Name', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
            brush: brush,
            bounds: const Rect.fromLTWH(0, 60, 250, 30)
          );
          
          graphics.drawString('123 Company Street\nCity, State ZIP\nPhone: (555) 123-4567', normalFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 90, 250, 60)
          );
          
          graphics.drawString('Invoice #: 0001\nDate: [Current Date]\nDue Date: [Due Date]', normalFont,
            brush: brush,
            bounds: const Rect.fromLTWH(300, 90, 200, 60)
          );
          
          graphics.drawString('BILL TO:', PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
            brush: brush,
            bounds: const Rect.fromLTWH(0, 170, 200, 20)
          );
          
          graphics.drawString('[Client Name]\n[Client Company]\n[Street Address]\n[City, State ZIP]', normalFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 190, 250, 80)
          );
          
          // Draw table headers
          graphics.drawRectangle(
            pen: PdfPen(PdfColor(0, 0, 0)),
            brush: PdfSolidBrush(PdfColor(220, 220, 220)),
            bounds: const Rect.fromLTWH(0, 290, 500, 30)
          );
          
          graphics.drawString('Description', PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
            brush: PdfSolidBrush(PdfColor(0, 0, 0)),
            bounds: const Rect.fromLTWH(10, 295, 250, 20)
          );
          
          graphics.drawString('Qty', PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
            brush: PdfSolidBrush(PdfColor(0, 0, 0)),
            bounds: const Rect.fromLTWH(270, 295, 40, 20)
          );
          
          graphics.drawString('Unit Price', PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
            brush: PdfSolidBrush(PdfColor(0, 0, 0)),
            bounds: const Rect.fromLTWH(340, 295, 70, 20)
          );
          
          graphics.drawString('Amount', PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
            brush: PdfSolidBrush(PdfColor(0, 0, 0)),
            bounds: const Rect.fromLTWH(430, 295, 70, 20)
          );
          
          // Sample line items
          int y = 330;
          for (int i = 1; i <= 3; i++) {
            graphics.drawString('[Item $i Description]', normalFont,
              brush: brush,
              bounds: Rect.fromLTWH(10, y.toDouble(), 250, 20)
            );
            
            graphics.drawString('1', normalFont,
              brush: brush,
              bounds: Rect.fromLTWH(270, y.toDouble(), 40, 20)
            );
            
            graphics.drawString('\$100.00', normalFont,
              brush: brush,
              bounds: Rect.fromLTWH(340, y.toDouble(), 70, 20)
            );
            
            graphics.drawString('\$100.00', normalFont,
              brush: brush,
              bounds: Rect.fromLTWH(430, y.toDouble(), 70, 20)
            );
            
            y += 30;
          }
          
          // Draw total
          graphics.drawLine(
            PdfPen(PdfColor(0, 0, 0)),
            Offset(340, y.toDouble()),
            Offset(500, y.toDouble())
          );
          
          graphics.drawString('Total:', PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
            brush: brush,
            bounds: Rect.fromLTWH(340, y + 10.toDouble(), 70, 20)
          );
          
          graphics.drawString('\$300.00', PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
            brush: brush,
            bounds: Rect.fromLTWH(430, y + 10.toDouble(), 70, 20)
          );
          
          content = 'Invoice template created';
          break;
        
        case 'Report':
          // Draw report template
          graphics.drawString('REPORT', headerFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 0, 500, 40),
            format: PdfStringFormat(alignment: PdfTextAlignment.center)
          );
          
          graphics.drawString('[Report Title]', PdfStandardFont(PdfFontFamily.helvetica, 16),
            brush: brush,
            bounds: const Rect.fromLTWH(0, 60, 500, 30),
            format: PdfStringFormat(alignment: PdfTextAlignment.center)
          );
          
          graphics.drawString('Prepared by: [Your Name]\nDate: [Current Date]', normalFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 100, 500, 40),
            format: PdfStringFormat(alignment: PdfTextAlignment.center)
          );
          
          graphics.drawLine(
            PdfPen(PdfColor(0, 0, 0)),
            Offset(0, 150),
            Offset(page.getClientSize().width, 150)
          );
          
          graphics.drawString('1. INTRODUCTION', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
            brush: brush,
            bounds: const Rect.fromLTWH(0, 170, 500, 30)
          );
          
          graphics.drawString('[Write an introduction to your report here. Explain the purpose, scope, and methodology used.]', normalFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 200, 500, 60)
          );
          
          graphics.drawString('2. FINDINGS', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
            brush: brush,
            bounds: const Rect.fromLTWH(0, 270, 500, 30)
          );
          
          graphics.drawString('[Summarize your main findings here. You can use bullet points or paragraphs.]', normalFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 300, 500, 60)
          );
          
          graphics.drawString('3. CONCLUSION', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
            brush: brush,
            bounds: const Rect.fromLTWH(0, 370, 500, 30)
          );
          
          graphics.drawString('[Write your conclusion here. Summarize the key points and provide any recommendations.]', normalFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 400, 500, 60)
          );
          
          content = 'Report template created';
          break;
          
        default:
          // Blank template with title
          graphics.drawString('New PDF Document', headerFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 0, 500, 40),
            format: PdfStringFormat(alignment: PdfTextAlignment.center)
          );
          
          graphics.drawString('Created: ${DateTime.now().toString().split('.')[0]}', normalFont,
            brush: brush,
            bounds: const Rect.fromLTWH(0, 60, 500, 30),
            format: PdfStringFormat(alignment: PdfTextAlignment.center)
          );
          
          content = 'Blank PDF created';
      }
      
      // Save the document to bytes
      final List<int> bytes = await document.save();
      
      // Save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final String fileName = '${tempDir.path}/${_nameController.text}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final File file = File(fileName);
      await file.writeAsBytes(bytes);
      
      // Update local file reference and content
      _localFile = file;
      _contentController.text = content;
      
      // Close the document
      document.dispose();
      
      // Rebuild to show the PDF
      setState(() {});
    } catch (e) {
      developer.log('Error creating PDF template: $e', name: 'DocumentDetailScreen');
      _contentController.text = 'Error creating PDF template: $e';
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

  // Load CSV content with proper formatting
  Future<void> _loadCsvContent(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        try {
          // Try to read as text
          final fileContent = await file.readAsString();
          _contentController.text = fileContent;
          
          // Also try to parse with Excel to verify it's valid
          await _parseCsvWithExcel();
        } catch (e) {
          developer.log('Error reading CSV file: $e', name: 'DocumentDetailScreen');
          _contentController.text = '[This CSV file could not be read as text. It might be corrupted or in an unsupported format.]';
        }
      }
    } catch (e) {
      developer.log('Error loading CSV content: $e', name: 'DocumentDetailScreen');
      rethrow;
    }
  }
  
  // Load DOCX content properly
  Future<void> _loadDocxContent(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        try {
          // For DOCX files, we can't easily display the content as text
          // So we just set a placeholder message
          _contentController.text = '[This document contains binary DOCX content that can only be viewed in the appropriate viewer.]';
          
          // We'll extract content when viewing
          final extracted = await _extractDocxContent();
          if (extracted.isNotEmpty) {
            _contentController.text = extracted.join('\n\n');
          }
        } catch (e) {
          developer.log('Error reading DOCX file: $e', name: 'DocumentDetailScreen');
          _contentController.text = '[This DOCX file could not be read. It might be corrupted or in an unsupported format.]';
        }
      }
    } catch (e) {
      developer.log('Error loading DOCX content: $e', name: 'DocumentDetailScreen');
      rethrow;
    }
  }
  
  // Load PDF content properly
  Future<void> _loadPdfContent(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        try {
          // For PDF files, we just set a placeholder since we can't easily extract text
          _contentController.text = '[This document contains PDF content that can be viewed in the PDF viewer.]';
          
          // Try to extract some metadata for display
          final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
          final meta = 'PDF Document\nPages: ${document.pages.count}\nSize: ${await file.length()} bytes';
          _contentController.text = meta;
          document.dispose();
        } catch (e) {
          developer.log('Error reading PDF file: $e', name: 'DocumentDetailScreen');
          _contentController.text = '[This PDF file could not be read. It might be corrupted or in an unsupported format.]';
        }
      }
    } catch (e) {
      developer.log('Error loading PDF content: $e', name: 'DocumentDetailScreen');
      rethrow;
    }
  }
  
  // Load generic file content
  Future<void> _loadGenericContent(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        try {
          final fileContent = await file.readAsString();
          _contentController.text = fileContent;
        } catch (e) {
          developer.log('Could not read file as text: $e', name: 'DocumentDetailScreen');
          _contentController.text = '[This document contains binary content that can only be viewed in the appropriate viewer.]';
        }
      }
    } catch (e) {
      developer.log('Error loading generic content: $e', name: 'DocumentDetailScreen');
      rethrow;
    }
  }

  // Helper method to extract content from DOCX file
  Future<List<String>> _extractDocxContent([File? file]) async {
    final targetFile = file ?? _localFile;
    
    if (targetFile == null || !targetFile.existsSync()) {
      return ['No file available to extract content from.'];
    }
    
    try {
      // Try to parse the DOCX file
      final docxBytes = await targetFile.readAsBytes();
      
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
        content.add("File: ${targetFile.path}");
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
          'File: ${targetFile.path}',
          '',
          'You can edit this document using the Edit button.',
        ];
      }
    } catch (e) {
      developer.log('Error reading DOCX file: $e', name: 'DocumentDetailScreen');
      return ['Error extracting content: $e'];
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
} 
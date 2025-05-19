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

import 'package:doc_manager/widgets/enhanced_document_editor.dart';

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
        _contentController.text = '';  // Initialize with empty string instead of document.content
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
      // First try to load from file path if available
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
            _contentController.text = '';
            
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
                            _contentController.text = '';
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
                Text("Tesdt" ?? 'No content'),
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
    
    setState(() {
      _isLoading = true;
    });

    // For new documents, we create a new document
    if (widget.isNewDocument) {
      // Check if we have a local file to use
      if (_localFile != null && _localFile!.existsSync()) {
        context.read<DocumentBloc>().add(
          AddDocument(
            folderId: widget.document.folderId,
            file: _localFile!,
            name: _nameController.text,
          ),
        );
        
        // Close the screen and return to the document list
        Navigator.pop(context);
      } else {
        // Create a new temporary file from text content, then add it
        _createTemporaryFileFromText().then((file) {
          if (file != null) {
            context.read<DocumentBloc>().add(
              AddDocument(
                folderId: widget.document.folderId,
                file: file,
                name: _nameController.text,
              ),
            );
            
            // Close the screen and return to the document list
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create document file')),
            );
            setState(() {
              _isLoading = false;
            });
          }
        });
      }
    } else {
      // For existing documents, we update the document
      try {
        // Check if we have a local file to use for content
        if (_localFile != null && _localFile!.existsSync()) {
          context.read<DocumentBloc>().add(
            UpdateDocument(
              id: widget.document.id,
              folderId: widget.document.folderId,
              name: _nameController.text,
              file: _localFile,
            ),
          );
          
          setState(() {
            _isEditing = false;
            _isLoading = false;
          });
        } else {
          // Create a new temporary file from text content, then update with it
          _createTemporaryFileFromText().then((file) {
            if (file != null) {
              context.read<DocumentBloc>().add(
                UpdateDocument(
                  id: widget.document.id,
                  folderId: widget.document.folderId,
                  name: _nameController.text,
                  file: file,
                ),
              );
              
              setState(() {
                _isEditing = false;
                _isLoading = false;
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to create document file')),
              );
              setState(() {
                _isLoading = false;
              });
            }
          });
        }
      } catch (e) {
        developer.log('Error saving document: $e', name: 'DocumentDetailScreen');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save document: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Helper method to create a temporary file from text content
  Future<File?> _createTemporaryFileFromText() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final String fileName = '${tempDir.path}/${_nameController.text}_${DateTime.now().millisecondsSinceEpoch}';
      final File file = File(fileName);
      await file.writeAsString(_contentController.text);
      return file;
    } catch (e) {
      developer.log('Error creating temporary file from text: $e', name: 'DocumentDetailScreen');
      return null;
    }
  }
  
  Widget _buildDocumentEditor() {
    if (_localFile == null) {
      return const Center(child: Text('Loading document...'));
    }
    
    // Use the EnhancedDocumentEditor for all document types
    return EnhancedDocumentEditor(
      file: _localFile!,
      documentType: _currentDocument?.type ?? widget.document.type,
      documentName: _nameController.text,
      readOnly: false,
      onSave: (File file) {
        // Update localFile with the saved file
        setState(() {
          _localFile = file;
        });
      },
    );
  }
  
  Widget _buildDocumentViewer() {
    if (_localFile == null) {
      // If file is not available, show appropriate message
      return const Center(child: CircularProgressIndicator());
    }
    
    // Use the EnhancedDocumentEditor in read-only mode
    return EnhancedDocumentEditor(
      file: _localFile!,
      documentType: _currentDocument?.type ?? widget.document.type,
      documentName: widget.document.name,
      readOnly: true,
      onSave: (File file) {
        // Update localFile with the saved file
        setState(() {
          _localFile = file;
        });
      },
    );
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
          await _parseCsvWithExcel(file);
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
  
  Future<List<List<dynamic>>> _parseCsvWithExcel([File? file]) async {
    try {
      final targetFile = file ?? _localFile;
      
      if (targetFile == null || !targetFile.existsSync()) {
        return [['No file available to parse.']];
      }
      
      developer.log('Parsing CSV file with Excel: ${targetFile.path}', name: 'DocumentDetailScreen');
      
      final bytes = await targetFile.readAsBytes();
      
      // Use Excel package to parse the file
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        return [['No data', 'found in', 'CSV file']];
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
        final targetFile = file ?? _localFile;
        if (targetFile == null || !targetFile.existsSync()) {
          return [['No file available to parse.']];
        }
        
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
        return [['Error', 'parsing', 'CSV file']];
      }
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

  // Apply a template based on document type and template name
  void _applyTemplate(String templateName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      String fileName = '${tempDir.path}/${_nameController.text}_${DateTime.now().millisecondsSinceEpoch}';
      
      switch (_currentDocument?.type ?? widget.document.type) {
        case DocumentType.csv:
          fileName += '.csv';
          final file = File(fileName);
          final content = _getTemplateContentForCsv(templateName);
          await file.writeAsString(content);
          _localFile = file;
          break;
          
        case DocumentType.docx:
          fileName += '.docx';
          final file = File(fileName);
          final content = _getTemplateContentForDocx(templateName);
          await file.writeAsString(content);
          _localFile = file;
          break;
          
        case DocumentType.pdf:
          fileName += '.pdf';
          final file = File(fileName);
          // Create a simple PDF with template content
          final document = PdfDocument();
          final page = document.pages.add();
          final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
          page.graphics.drawString(
            'Template: $templateName\nCreated: ${DateTime.now()}', 
            font, 
            bounds: Rect.fromLTWH(0, 0, 500, 30)
          );
          await file.writeAsBytes(await document.save());
          document.dispose();
          _localFile = file;
          break;
          
        default:
          throw Exception('Unsupported document type');
      }
      
      setState(() {});
    } catch (e) {
      developer.log('Error applying template: $e', name: 'DocumentDetailScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply template: $e')),
      );
    }
  }
  
  String _getTemplateContentForCsv(String templateName) {
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
    
    return buffer.toString();
  }
  
  String _getTemplateContentForDocx(String templateName) {
    switch (templateName) {
      case 'Letter':
        return '''[Your Name]
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
      case 'Resume':
        return '''JOHN DOE
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
      default:
        return 'Enter your document content here.';
    }
  }
} 
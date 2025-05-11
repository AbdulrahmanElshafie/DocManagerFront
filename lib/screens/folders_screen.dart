import 'package:doc_manager/blocs/folder/folder_bloc.dart';
import 'package:doc_manager/blocs/folder/folder_event.dart';
import 'package:doc_manager/blocs/folder/folder_state.dart';
import 'package:doc_manager/blocs/document/document_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/blocs/document/document_state.dart';
import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/models/folder.dart';
import 'package:doc_manager/screens/document_detail_screen.dart';
import 'package:doc_manager/shared/components/responsive_builder.dart';
import 'package:doc_manager/repository/folder_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:path/path.dart' as p;

class FoldersScreen extends StatefulWidget {
  final String? parentFolderId;
  
  const FoldersScreen({super.key, this.parentFolderId});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  late FolderBloc _folderBloc;
  late DocumentBloc _documentBloc;
  final _folderNameController = TextEditingController();
  final _documentNameController = TextEditingController();
  final _searchController = TextEditingController();
  
  List<Folder> _folders = [];
  List<Document> _documents = [];
  bool _isLoadingFolders = false;
  bool _isLoadingDocuments = false;
  
  // For file upload
  File? _selectedFile;
  String? _selectedFileName;
  bool _isUploadingDocument = false;
  
  // For breadcrumb navigation
  List<Folder> _folderPath = [];
  
  // For document creation
  DocumentType _selectedDocType = DocumentType.pdf;
  
  @override
  void initState() {
    super.initState();
    _folderBloc = context.read<FolderBloc>();
    _documentBloc = context.read<DocumentBloc>();
    _loadContent();
    _loadFolderPath();
  }
  
  void _loadContent() {
    _loadFolders();
    _loadDocuments();
  }
  
  void _loadFolders() {
    setState(() {
      _isLoadingFolders = true;
    });
    _folderBloc.add(GetFolders(parentFolderId: widget.parentFolderId));
  }
  
  void _loadDocuments() {
    setState(() {
      _isLoadingDocuments = true;
    });
    _documentBloc.add(LoadDocuments(folderId: widget.parentFolderId));
  }

  void _loadFolderPath() async {
    if (widget.parentFolderId == null) {
      setState(() {
        _folderPath = [];
      });
      return;
    }

    List<Folder> path = [];
    String? currentFolderId = widget.parentFolderId;
    
    while (currentFolderId != null && currentFolderId.isNotEmpty) {
      try {
        // Load the current folder
        Folder folder = await _folderBloc.state is FolderLoaded && (_folderBloc.state as FolderLoaded).folder.id == currentFolderId
            ? (_folderBloc.state as FolderLoaded).folder
            : await context.read<FolderRepository>().getFolder(currentFolderId);
            
        // Add to the beginning of the path
        path.insert(0, folder);
        
        // Move up one level
        currentFolderId = folder.parentId?.isNotEmpty == true ? folder.parentId : null;
      } catch (e) {
        developer.log('Error loading folder path: $e', name: 'FoldersScreen');
        break;
      }
    }
    
    setState(() {
      _folderPath = path;
    });
  }

  void _createFolder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: _folderNameController,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_folderNameController.text.isNotEmpty) {
                _folderBloc.add(CreateFolder(
                  name: _folderNameController.text,
                  parentFolderId: widget.parentFolderId,
                ));
                _folderNameController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  void _deleteFolder(Folder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Are you sure you want to delete "${folder.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _folderBloc.add(DeleteFolder(id: folder.id));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _createDocument() {
    // Reset state
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _documentNameController.clear();
      _selectedDocType = DocumentType.pdf;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create New Document'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose an option:'),
                  const SizedBox(height: 16),
                  
                  // Option 1: Upload existing document
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Document'),
                    onPressed: () async {
                      try {
                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'docx', 'csv'],
                          withData: true, // Ensure we get file data
                          withReadStream: true, // Enable read stream for large files
                        );
                        
                        if (result != null) {
                          if (result.files.single.path == null && !kIsWeb) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error: Could not get file path')),
                            );
                            return;
                          }
                          
                          setState(() {
                            if (!kIsWeb && result.files.single.path != null) {
                              _selectedFile = File(result.files.single.path!);
                              developer.log('Selected file path: ${_selectedFile!.path}', name: 'FoldersScreen');
                              developer.log('File exists: ${_selectedFile!.existsSync()}', name: 'FoldersScreen');
                            } else if (kIsWeb) {
                              developer.log('Web platform detected, will use file bytes', name: 'FoldersScreen');
                              // For web, we would handle this differently - to be implemented
                            }
                            
                            _selectedFileName = result.files.single.name;
                            _documentNameController.text = result.files.single.name;
                            
                            // Set document type based on file extension
                            final extension = p.extension(result.files.single.name).toLowerCase();
                            developer.log('File extension: $extension', name: 'FoldersScreen');
                            
                            if (extension == '.pdf') {
                              _selectedDocType = DocumentType.pdf;
                            } else if (extension == '.docx') {
                              _selectedDocType = DocumentType.docx;
                            } else if (extension == '.csv') {
                              _selectedDocType = DocumentType.csv;
                            } else {
                              // Default to PDF if extension not recognized
                              _selectedDocType = DocumentType.pdf;
                              developer.log('Unknown extension, defaulting to PDF', name: 'FoldersScreen');
                            }
                          });
                        }
                      } catch (e) {
                        developer.log('Error picking file: $e', name: 'FoldersScreen');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error selecting file: $e')),
                        );
                      }
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  if (_selectedFileName != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected: $_selectedFileName'),
                          if (_selectedFile != null) 
                            Text('File size: ${(_selectedFile!.lengthSync() / 1024).round()} KB'),
                        ],
                      ),
                    ),
                  
                  const Divider(height: 24),
                  const Text('OR'),
                  const Divider(height: 24),
                  
                  // Option 2: Create new document
                  const Text('Create a new document:'),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _documentNameController,
                    decoration: const InputDecoration(
                      labelText: 'Document Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  DropdownButtonFormField<DocumentType>(
                    value: _selectedDocType,
                    decoration: const InputDecoration(
                      labelText: 'Document Type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: DocumentType.pdf,
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf, color: Colors.red.shade800),
                            const SizedBox(width: 8),
                            const Text('PDF Document'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: DocumentType.docx,
                        child: Row(
                          children: [
                            Icon(Icons.description, color: Colors.blue.shade800),
                            const SizedBox(width: 8),
                            const Text('Word Document (.docx)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: DocumentType.csv,
                        child: Row(
                          children: [
                            Icon(Icons.table_chart, color: Colors.green.shade800),
                            const SizedBox(width: 8),
                            const Text('Spreadsheet (.csv)'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDocType = value;
                        });
                        
                        // Apply appropriate extension if name doesn't have one already
                        if (_documentNameController.text.isNotEmpty) {
                          String name = _documentNameController.text;
                          String extension = '';
                          
                          switch (value) {
                            case DocumentType.pdf:
                              extension = '.pdf';
                              break;
                            case DocumentType.docx:
                              extension = '.docx';
                              break;
                            case DocumentType.csv:
                              extension = '.csv';
                              break;
                          }
                          
                          // Only update if no extension or different extension
                          if (!name.contains('.') || !name.toLowerCase().endsWith(extension)) {
                            // Remove existing extension if any
                            if (name.contains('.')) {
                              name = name.split('.')[0];
                            }
                            
                            // Add new extension
                            setState(() {
                              _documentNameController.text = name + extension;
                            });
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              if (_isUploadingDocument)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: () async {
                    if (_documentNameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a document name')),
                      );
                      return;
                    }
                    
                    setState(() {
                      _isUploadingDocument = true;
                    });
                    
                    try {
                      // Log start of document creation
                      developer.log('Starting document creation/upload', name: 'FoldersScreen');
                      
                      if (_selectedFile != null) {
                        // Option 1: Upload existing file
                        developer.log(
                          'Uploading document file: ${_selectedFile!.path}, ' +
                          'name: ${_documentNameController.text}, ' +
                          'folderId: ${widget.parentFolderId ?? "root"}', 
                          name: 'FoldersScreen'
                        );
                        
                        // Check if file exists and is readable
                        if (!_selectedFile!.existsSync()) {
                          throw Exception('Selected file does not exist');
                        }
                        
                        _documentBloc.add(AddDocument(
                          file: _selectedFile!,
                          name: _documentNameController.text,
                          folderId: widget.parentFolderId,
                        ));
                        
                        developer.log('AddDocument event dispatched', name: 'FoldersScreen');
                        Navigator.pop(context);
                      } else {
                        // Option 2: Create new document with proper validation
                        final String name = _documentNameController.text;
                        
                        // Ensure it has the right extension
                        String finalName = name;
                        String extension = p.extension(name).toLowerCase();
                        
                        if (extension.isEmpty) {
                          // Add extension if none exists
                          switch (_selectedDocType) {
                            case DocumentType.pdf:
                              finalName = '$name.pdf';
                              break;
                            case DocumentType.docx:
                              finalName = '$name.docx';
                              break;
                            case DocumentType.csv:
                              finalName = '$name.csv';
                              break;
                          }
                        } else if (
                          (extension != '.pdf' && _selectedDocType == DocumentType.pdf) ||
                          (extension != '.docx' && _selectedDocType == DocumentType.docx) ||
                          (extension != '.csv' && _selectedDocType == DocumentType.csv)
                        ) {
                          // Extension doesn't match type, replace it
                          final nameWithoutExt = p.basenameWithoutExtension(name);
                          switch (_selectedDocType) {
                            case DocumentType.pdf:
                              finalName = '$nameWithoutExt.pdf';
                              break;
                            case DocumentType.docx:
                              finalName = '$nameWithoutExt.docx';
                              break;
                            case DocumentType.csv:
                              finalName = '$nameWithoutExt.csv';
                              break;
                          }
                        }
                        
                        // Create an empty document with initial content
                        String initialContent = '';
                        switch (_selectedDocType) {
                          case DocumentType.csv:
                            initialContent = 'Column A,Column B,Column C\nValue 1,Value 2,Value 3';
                            break;
                          case DocumentType.docx:
                            initialContent = 'This is a new document. Start typing here...';
                            break;
                          case DocumentType.pdf:
                            initialContent = 'This content will be converted to PDF format.';
                            break;
                        }
                        
                        developer.log(
                          'Creating new document with name: $finalName, ' +
                          'type: $_selectedDocType, ' +
                          'folderId: ${widget.parentFolderId ?? "root"}',
                          name: 'FoldersScreen'
                        );
                        
                        _documentBloc.add(CreateDocument(
                          name: finalName,
                          content: initialContent,
                          folderId: widget.parentFolderId,
                        ));
                        
                        developer.log('CreateDocument event dispatched', name: 'FoldersScreen');
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      developer.log('Error creating document: $e', name: 'FoldersScreen');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isUploadingDocument = false;
                        });
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
            ],
          );
        },
      ),
    );
  }
  
  void _deleteDocument(Document document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${document.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _documentBloc.add(DeleteDocument(document.id, folderId: widget.parentFolderId));
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
        title: Text(widget.parentFolderId == null ? 'My Files' : 'Folder Contents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: FolderSearchDelegate(folderBloc: _folderBloc),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContent,
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<FolderBloc, FolderState>(
            listener: (context, state) {
              if (state is FolderError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Folder Error: ${state.error}')),
                );
              } else if (state is FolderOperationSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
                _loadContent(); // Reload when folder operations complete
                _loadFolderPath(); // Reload folder path
              } else if (state is FoldersLoaded) {
                setState(() {
                  _folders = state.folders;
                  _isLoadingFolders = false;
                });
              }
            },
          ),
          BlocListener<DocumentBloc, DocumentState>(
            listener: (context, state) {
              if (state is DocumentError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Document Error: ${state.error}')),
                );
              } else if (state is DocumentOperationSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
                _loadContent(); // Reload when document operations complete
              } else if (state is DocumentCreated) {
                // Navigate to the newly created document
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => DocumentDetailScreen(
                      document: state.document,
                      isEditing: true,
                    ),
                  ),
                ).then((_) => _loadContent()); // Reload on navigation back
              } else if (state is DocumentsLoaded) {
                setState(() {
                  _documents = state.documents;
                  _isLoadingDocuments = false;
                });
              }
            },
          ),
        ],
        child: Column(
          children: [
            _buildBreadcrumbNavigation(),
            Expanded(child: _buildRefreshableContent()),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'createDocument',
            onPressed: _createDocument,
            child: const Icon(Icons.add),
            backgroundColor: Colors.blue,
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'createFolder',
            onPressed: _createFolder,
            child: const Icon(Icons.create_new_folder),
            backgroundColor: Colors.amber,
          ),
        ],
      ),
    );
  }
  
  Widget _buildBreadcrumbNavigation() {
    List<Widget> breadcrumbs = [];
    
    // Add the root link
    breadcrumbs.add(
      InkWell(
        onTap: () {
          if (widget.parentFolderId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const FoldersScreen(),
              ),
            );
          }
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home, size: 16),
              SizedBox(width: 4),
              Text('Root'),
            ],
          ),
        ),
      ),
    );
    
    // Add path segments
    for (int i = 0; i < _folderPath.length; i++) {
      // Add separator
      if (i > 0 || breadcrumbs.isNotEmpty) {
        breadcrumbs.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.chevron_right, size: 16),
          ),
        );
      }
      
      final folder = _folderPath[i];
      final isLast = i == _folderPath.length - 1;
      
      breadcrumbs.add(
        InkWell(
          onTap: isLast ? null : () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FoldersScreen(parentFolderId: folder.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              folder.name,
              style: TextStyle(
                fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                decoration: isLast ? TextDecoration.none : TextDecoration.underline,
              ),
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: breadcrumbs),
      ),
    );
  }
  
  Widget _buildRefreshableContent() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadContent();
        // Wait for loading to complete
        await Future.delayed(const Duration(seconds: 1));
      },
      child: _isLoadingFolders || _isLoadingDocuments
          ? const Center(child: CircularProgressIndicator())
          : _buildContentView(),
    );
  }
  
  Widget _buildContentView() {
    if (_folders.isEmpty && _documents.isEmpty) {
      return _buildEmptyState();
    }
    
    return ResponsiveBuilder(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
  
  Widget _buildEmptyState() {
    // Custom empty state that's wrapped in a ListView to work with RefreshIndicator
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open,
                  size: 72,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'This folder is empty',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create new folders or documents!',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _createFolder,
                      icon: const Icon(Icons.create_new_folder),
                      label: const Text('New Folder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _createDocument,
                      icon: const Icon(Icons.add),
                      label: const Text('New Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMobileLayout() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (_folders.isNotEmpty)
          ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ..._folders.map((folder) => _buildFolderListItem(folder)).toList(),
            const Divider(height: 32),
          ],
        if (_documents.isNotEmpty)
          ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ..._documents.map((doc) => _buildDocumentListItem(doc)).toList(),
          ],
      ],
    );
  }
  
  Widget _buildTabletLayout() {
    return CustomScrollView(
      slivers: [
        if (_folders.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildFolderCard(_folders[index]),
              childCount: _folders.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(height: 32),
          ),
        ],
        if (_documents.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildDocumentCard(_documents[index]),
              childCount: _documents.length,
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildDesktopLayout() {
    return CustomScrollView(
      slivers: [
        if (_folders.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildFolderCard(_folders[index]),
              childCount: _folders.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(height: 48),
          ),
        ],
        if (_documents.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.5,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildDocumentCard(_documents[index]),
              childCount: _documents.length,
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildFolderCard(Folder folder) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FoldersScreen(parentFolderId: folder.id),
            ),
          ).then((_) => _loadContent()); // Reload on navigation back
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.amber.shade100,
                child: Center(
                  child: Icon(
                    Icons.folder,
                    size: 64,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      folder.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteFolder(folder);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFolderListItem(Folder folder) {
    return ListTile(
      leading: const Icon(Icons.folder, color: Colors.amber),
      title: Text(folder.name),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () => _deleteFolder(folder),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoldersScreen(parentFolderId: folder.id),
          ),
        ).then((_) => _loadContent()); // Reload on navigation back
      },
    );
  }
  
  Widget _buildDocumentCard(Document document) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => DocumentDetailScreen(document: document),
            ),
          ).then((_) => _loadContent()); // Reload on navigation back
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.blue.shade100,
              height: 70,
              width: double.infinity,
              child: Center(
                child: _buildDocumentIcon(document),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Modified: ${document.updatedAt?.toString().split(' ')[0] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          constraints: const BoxConstraints(maxHeight: 32),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (context) => DocumentDetailScreen(document: document, isEditing: true),
                              ),
                            ).then((_) => _loadContent()); // Reload on navigation back
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          constraints: const BoxConstraints(maxHeight: 32),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _deleteDocument(document);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDocumentIcon(Document document) {
    switch (document.type) {
      case DocumentType.pdf:
        return Icon(
          Icons.picture_as_pdf,
          size: 40,
          color: Colors.red.shade800,
        );
      case DocumentType.csv:
        return Icon(
          Icons.table_chart,
          size: 40,
          color: Colors.green.shade800,
        );
      case DocumentType.docx:
        return Icon(
          Icons.description,
          size: 40,
          color: Colors.blue.shade800,
        );
      default:
        return Icon(
          Icons.insert_drive_file,
          size: 40,
          color: Colors.blue.shade800,
        );
    }
  }
  
  Widget _buildDocumentListItem(Document document) {
    return ListTile(
      leading: _buildDocumentIcon(document),
      title: Text(document.name),
      subtitle: Text('Last modified: ${document.updatedAt?.toString().split('.')[0] ?? 'N/A'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => DocumentDetailScreen(document: document, isEditing: true),
                ),
              ).then((_) => _loadContent()); // Reload on navigation back
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _deleteDocument(document);
            },
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) => DocumentDetailScreen(document: document),
          ),
        ).then((_) => _loadContent()); // Reload on navigation back
      },
    );
  }
  
  @override
  void dispose() {
    _folderNameController.dispose();
    _documentNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class FolderSearchDelegate extends SearchDelegate<String> {
  final FolderBloc folderBloc;
  
  FolderSearchDelegate({required this.folderBloc});
  
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }
  
  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }
  
  @override
  Widget buildResults(BuildContext context) {
    folderBloc.add(SearchFolders(query: query));
    return BlocBuilder<FolderBloc, FolderState>(
      builder: (context, state) {
        if (state is FolderLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is FoldersLoaded) {
          final folders = state.folders;
          if (folders.isEmpty) {
            return const Center(child: Text('No folders found'));
          }
          
          return ListView.builder(
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(folder.name),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FoldersScreen(parentFolderId: folder.id),
                    ),
                  );
                  close(context, folder.id);
                },
              );
            },
          );
        } else if (state is FolderError) {
          return Center(child: Text('Error: ${state.error}'));
        }
        
        return const Center(child: Text('Search for folders'));
      },
    );
  }
  
  @override
  Widget buildSuggestions(BuildContext context) {
    // Just return empty container for suggestions
    return Container();
  }
} 
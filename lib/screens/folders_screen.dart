import 'package:doc_manager/blocs/folder/folder_bloc.dart';
import 'package:doc_manager/blocs/folder/folder_event.dart';
import 'package:doc_manager/blocs/folder/folder_state.dart';
import 'package:doc_manager/blocs/document/document_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/blocs/document/document_state.dart';
import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/models/folder.dart';
import 'package:doc_manager/shared/components/responsive_builder.dart';
import 'package:doc_manager/repository/folder_repository.dart';
import 'package:doc_manager/screens/document_viewer_screen.dart';
import 'package:doc_manager/shared/network/api_service.dart';
import 'package:doc_manager/shared/network/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:io' as io show File;
import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';
import '../shared/utils/file_utils.dart';
import '../shared/utils/web_download_helper_stub.dart'
    if (dart.library.html) '../shared/utils/web_download_helper.dart';
import 'package:path/path.dart' as p;

class FoldersScreen extends StatefulWidget {
  final String? parentFolderId;
  final VoidCallback? onReturnToRoot; // Add callback for root return
  
  const FoldersScreen({super.key, this.parentFolderId, this.onReturnToRoot});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> with WidgetsBindingObserver {
  late FolderBloc _folderBloc;
  late DocumentBloc _documentBloc;
  final _folderNameController = TextEditingController();
  final _documentNameController = TextEditingController();
  final _searchController = TextEditingController();
  
  List<Folder> _folders = [];
  List<Document> _documents = [];
  List<Folder> _filteredFolders = [];
  List<Document> _filteredDocuments = [];
  bool _isLoadingFolders = false;
  bool _isLoadingDocuments = false;
  Timer? _searchDebouncer;
  bool _isGridView = true; // Add view mode state
  
  // For file upload
  io.File? _selectedFile;
  String? _selectedFileName;
  bool _isUploadingDocument = false;
  
  // For breadcrumb navigation
  List<Folder> _folderPath = [];
  
  // For document creation
  DocumentType _selectedDocType = DocumentType.pdf;
  
  // For web platform
  List<int>? _selectedFileBytes;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _folderBloc = context.read<FolderBloc>();
    _documentBloc = context.read<DocumentBloc>();
    
    // Initialize filtered lists
    _filteredFolders = _folders;
    _filteredDocuments = _documents;
    
    _resetAndReloadContent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _folderNameController.dispose();
    _documentNameController.dispose();
    _searchController.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh content when app becomes active
    if (state == AppLifecycleState.resumed && mounted) {
      _resetAndReloadContent();
    }
  }

  void _resetAndReloadContent() {
    // Reset all state variables
    setState(() {
      _folders = [];
      _documents = [];
      _filteredFolders = [];
      _filteredDocuments = [];
      _isLoadingFolders = false;
      _isLoadingDocuments = false;
      _folderPath = [];
      _searchController.clear();
      _selectedFile = null;
      _selectedFileName = null;
      _selectedFileBytes = null;
      _isUploadingDocument = false;
    });
    
    // Load fresh content
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
                          withData: true, // Ensure we get file data for web
                          withReadStream: false, // Disable read stream for web compatibility
                        );
                        
                        if (result != null) {
                          // Check if we have a valid file selection
                          final pickedFile = result.files.single;
                          
                          if (kIsWeb) {
                            // For web, we need the bytes
                            if (pickedFile.bytes == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error: Could not read file data on web')),
                              );
                              return;
                            }
                            
                            setState(() {
                              // For web, we store the bytes and create a virtual file reference
                              _selectedFile = null; // We don't use File objects on web
                              _selectedFileBytes = pickedFile.bytes;
                              _selectedFileName = pickedFile.name;
                              _documentNameController.text = pickedFile.name;
                              
                              // Set document type based on file extension
                              final extension = p.extension(pickedFile.name).toLowerCase();
                              developer.log('File extension: $extension', name: 'FoldersScreen');
                              
                              if (extension == '.pdf') {
                                _selectedDocType = DocumentType.pdf;
                              } else if (extension == '.docx') {
                                _selectedDocType = DocumentType.docx;
                              } else if (extension == '.csv') {
                                _selectedDocType = DocumentType.csv;
                              } else {
                                _selectedDocType = DocumentType.pdf;
                                developer.log('Unknown extension, defaulting to PDF', name: 'FoldersScreen');
                              }
                              
                              developer.log('Web platform: selected file ${pickedFile.name}, size: ${pickedFile.bytes!.length} bytes', name: 'FoldersScreen');
                            });
                          } else {
                            // For non-web platforms, check file path
                            if (pickedFile.path == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error: Could not get file path')),
                              );
                              return;
                            }
                            
                            setState(() {
                              if (!kIsWeb) {
                                io.File? newSelectedFile;
                                if (!kIsWeb) {
                                  newSelectedFile = io.File(pickedFile.path!);
                                }
                                _selectedFile = newSelectedFile;
                                _selectedFileBytes = null;
                                developer.log('Selected file path: ${FileUtils.getFilePath(_selectedFile)}', name: 'FoldersScreen');
                                developer.log('File exists: ${FileUtils.existsSync(_selectedFile!)}', name: 'FoldersScreen');
                              } else {
                                _selectedFile = null;
                                _selectedFileBytes = null;
                                developer.log('Web platform: file operations not supported', name: 'FoldersScreen');
                              }
                              
                              _selectedFileName = pickedFile.name;
                              _documentNameController.text = pickedFile.name;
                              
                              // Set document type based on file extension
                              final extension = p.extension(pickedFile.name).toLowerCase();
                              developer.log('File extension: $extension', name: 'FoldersScreen');
                              
                              if (extension == '.pdf') {
                                _selectedDocType = DocumentType.pdf;
                              } else if (extension == '.docx') {
                                _selectedDocType = DocumentType.docx;
                              } else if (extension == '.csv') {
                                _selectedDocType = DocumentType.csv;
                              } else {
                                _selectedDocType = DocumentType.pdf;
                                developer.log('Unknown extension, defaulting to PDF', name: 'FoldersScreen');
                              }
                            });
                          }
                        }
                      } catch (e) {
                        developer.log('Error picking file: $e', name: 'FoldersScreen');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error picking file: $e')),
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
                            Text('File size: ${(FileUtils.lengthSync(_selectedFile!) / 1024).round()} KB'),
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
                            case DocumentType.unsupported:
                              extension = '';
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
                      
                      if (_selectedFile != null || _selectedFileBytes != null) {
                        // Option 1: Upload existing file
                        if (kIsWeb && _selectedFileBytes != null) {
                          developer.log(
                            'Uploading document file bytes on web: ' +
                            'name: ${_documentNameController.text}, ' +
                            'size: ${_selectedFileBytes!.length} bytes, ' +
                            'folderId: ${widget.parentFolderId ?? "root"}', 
                            name: 'FoldersScreen'
                          );
                          
                          _documentBloc.add(AddDocumentFromBytes(
                            fileBytes: _selectedFileBytes!,
                            fileName: _selectedFileName!,
                            name: _documentNameController.text,
                            folderId: widget.parentFolderId,
                          ));
                        } else if (!kIsWeb && _selectedFile != null) {
                          developer.log(
                            'Uploading document file: ${FileUtils.getFilePath(_selectedFile) ?? "unknown_path"}, ' +
                            'name: ${_documentNameController.text}, ' +
                            'folderId: ${widget.parentFolderId ?? "root"}', 
                            name: 'FoldersScreen'
                          );
                          
                          // Check if file exists and is readable
                          if (!FileUtils.existsSync(_selectedFile!)) {
                            throw Exception('Selected file does not exist');
                          }
                          
                          _documentBloc.add(AddDocument(
                            file: _selectedFile!,
                            name: _documentNameController.text,
                            folderId: widget.parentFolderId,
                          ));
                        } else {
                          throw Exception('No valid file selected for current platform');
                        }
                        
                        developer.log('Document upload event dispatched', name: 'FoldersScreen');
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
                            case DocumentType.unsupported:
                              finalName = name;
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
                            case DocumentType.unsupported:
                              finalName = nameWithoutExt;
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
                          case DocumentType.unsupported:
                            initialContent = '';
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Delete the document - the BlocListener will handle success/error messages
              // and the BlocBuilder will automatically refresh the list when the state changes
              _documentBloc.add(DeleteDocument(document.id, folderId: widget.parentFolderId));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _downloadDocument(Document document) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Downloading document...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // Download the document using the API service
      final apiService = ApiService();
      final downloadUrl = '${API.baseUrl}/manager/document/${document.id}/download/';
      
      // Ensure filename has proper extension
      final fileName = _ensureFileExtension(document.name, document.type);
      
      if (kIsWeb) {
        // For web, programmatically trigger download
        try {
          final fileBytes = await apiService.downloadFile(downloadUrl);
          
          // Use the web download helper with proper filename
          WebDownloadHelper.downloadFile(Uint8List.fromList(fileBytes), fileName);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document downloaded successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          // Show error message if download fails
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // For mobile/desktop, download and save to documents directory
        final fileBytes = await apiService.downloadFile(downloadUrl);
        
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = io.File(filePath);
        await file.writeAsBytes(fileBytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document downloaded to: $filePath'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open Folder',
                onPressed: () {
                  // TODO: Open file manager to show the file
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to ensure filename has proper extension
  String _ensureFileExtension(String fileName, DocumentType documentType) {
    final extension = _getFileExtension(documentType);
    
    // Check if filename already has the correct extension
    if (fileName.toLowerCase().endsWith(extension.toLowerCase())) {
      return fileName;
    }
    
    // Remove any existing extension and add the correct one
    final nameWithoutExtension = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    
    return '$nameWithoutExtension$extension';
  }

  // Helper method to get file extension from document type
  String _getFileExtension(DocumentType documentType) {
    switch (documentType) {
      case DocumentType.pdf:
        return '.pdf';
      case DocumentType.csv:
        return '.csv';
      case DocumentType.docx:
        return '.docx';
      case DocumentType.unsupported:
        return '.txt';
    }
  }

  void _uploadFolder() {
    showDialog(
      context: context,
      builder: (context) => _UploadFolderDialog(
        parentFolderId: widget.parentFolderId,
        onFolderUploaded: () {
          _loadContent();
        },
      ),
    );
  }

  void _shareDocument(Document document) {
    showDialog(
      context: context,
      builder: (context) => _ShareDialog(
        documentId: document.id,
        documentName: document.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.parentFolderId == null, // Allow normal pop at root level
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (widget.parentFolderId != null) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.parentFolderId == null ? 'My Files' : 'Folder Contents'),
          leading: widget.parentFolderId != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBackNavigation,
                )
              : null,
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
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
              tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
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
                  _filterContent(_searchController.text);
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
                } else if (state is DocumentDeletedWithList) {
                  // Handle optimized delete success
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Document deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Update local state with optimized document list
                  setState(() {
                    _documents = state.documents ?? [];
                    _isLoadingDocuments = false;
                  });
                  _filterContent(_searchController.text);
                } else if (state is DocumentCreatedWithList) {
                  // Handle document creation success
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Document created successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Update local state with new document list
                  setState(() {
                    _documents = state.documents;
                    _isLoadingDocuments = false;
                  });
                  _filterContent(_searchController.text);
                  // Navigate to the newly created document
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => DocumentViewerScreen(
                        document: state.document,
                      ),
                    ),
                  ).then((_) => _loadContent()); // Reload on navigation back
                } else if (state is DocumentUpdatedWithList) {
                  // Handle document update success
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Document updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Update local state with updated document list
                  if (state.documents != null) {
                    setState(() {
                      _documents = state.documents!;
                      _isLoadingDocuments = false;
                    });
                    _filterContent(_searchController.text);
                  }
                } else if (state is DocumentCreated) {
                  // Navigate to the newly created document (fallback for old state)
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => DocumentViewerScreen(
                        document: state.document,
                      ),
                    ),
                  ).then((_) => _loadContent()); // Reload on navigation back
                } else if (state is DocumentsLoaded) {
                  setState(() {
                    _documents = state.documents;
                    _isLoadingDocuments = false;
                  });
                  _filterContent(_searchController.text);
                }
              },
            ),
          ],
          child: Column(
            children: [
              _buildBreadcrumbNavigation(),
              _buildSearchBar(),
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
              heroTag: 'uploadFolder',
              onPressed: _uploadFolder,
              child: const Icon(Icons.upload),
              backgroundColor: Colors.green,
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
            _navigateToFolder(null); // Navigate to root
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.home, 
                size: 16,
                color: widget.parentFolderId != null 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 4),
              Text(
                'Root',
                style: TextStyle(
                  fontWeight: widget.parentFolderId != null 
                      ? FontWeight.normal 
                      : FontWeight.bold,
                  decoration: widget.parentFolderId != null 
                      ? TextDecoration.underline 
                      : TextDecoration.none,
                  color: widget.parentFolderId != null 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right, 
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
      
      final folder = _folderPath[i];
      final isLast = i == _folderPath.length - 1;
      
      breadcrumbs.add(
        InkWell(
          onTap: isLast ? null : () {
            _navigateToFolder(folder.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              folder.name,
              style: TextStyle(
                fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                decoration: isLast ? TextDecoration.none : TextDecoration.underline,
                color: isLast 
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.primary,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: breadcrumbs.map((breadcrumb) {
            // Apply consistent styling to breadcrumb items
            if (breadcrumb is InkWell) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (breadcrumb as InkWell).onTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: (breadcrumb.child as Padding).child,
                  ),
                ),
              );
            }
            return breadcrumb;
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search folders and documents...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.background,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ],
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
    if (_filteredFolders.isEmpty && _filteredDocuments.isEmpty) {
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
                Text(
                  _searchController.text.isNotEmpty 
                      ? 'No results found' 
                      : 'This folder is empty',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchController.text.isNotEmpty 
                      ? 'Try a different search term'
                      : 'Create new folders or documents!',
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
    if (_isGridView) {
      return CustomScrollView(
        slivers: [
          if (_filteredFolders.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildFolderCard(_filteredFolders[index]),
                childCount: _filteredFolders.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: Divider(height: 32),
            ),
          ],
          if (_filteredDocuments.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 6, // Further reduced from 8
                mainAxisSpacing: 6,  // Further reduced from 8
                childAspectRatio: 1.1, // Reduced from 1.4 (taller cards)
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildDocumentCard(_filteredDocuments[index]),
                childCount: _filteredDocuments.length,
              ),
            ),
          ],
        ],
      );
    } else {
      return ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (_filteredFolders.isNotEmpty)
            ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              ..._filteredFolders.map((folder) => _buildFolderListItem(folder)).toList(),
              const Divider(height: 32),
            ],
          if (_filteredDocuments.isNotEmpty)
            ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              ..._filteredDocuments.map((doc) => _buildDocumentListItem(doc)).toList(),
            ],
        ],
      );
    }
  }
  
  Widget _buildTabletLayout() {
    if (_isGridView) {
      return CustomScrollView(
        slivers: [
          if (_filteredFolders.isNotEmpty) ...[
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
                (context, index) => _buildFolderCard(_filteredFolders[index]),
                childCount: _filteredFolders.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: Divider(height: 32),
            ),
          ],
          if (_filteredDocuments.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8, // Further reduced from 10
                mainAxisSpacing: 8,  // Further reduced from 10
                childAspectRatio: 1.3, // Reduced from 1.6 (taller cards)
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildDocumentCard(_filteredDocuments[index]),
                childCount: _filteredDocuments.length,
              ),
            ),
          ],
        ],
      );
    } else {
      return ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (_filteredFolders.isNotEmpty)
            ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              ..._filteredFolders.map((folder) => _buildFolderListItem(folder)).toList(),
              const Divider(height: 32),
            ],
          if (_filteredDocuments.isNotEmpty)
            ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              ..._filteredDocuments.map((doc) => _buildDocumentListItem(doc)).toList(),
            ],
        ],
      );
    }
  }
  
  Widget _buildDesktopLayout() {
    if (_isGridView) {
      return CustomScrollView(
        slivers: [
          if (_filteredFolders.isNotEmpty) ...[
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
                (context, index) => _buildFolderCard(_filteredFolders[index]),
                childCount: _filteredFolders.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: Divider(height: 48),
            ),
          ],
          if (_filteredDocuments.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              ),
            ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12, // Further reduced from 16
                mainAxisSpacing: 12,  // Further reduced from 16
                childAspectRatio: 1.4, // Reduced from 1.7 (taller cards)
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildDocumentCard(_filteredDocuments[index]),
                childCount: _filteredDocuments.length,
              ),
            ),
          ],
        ],
      );
    } else {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_filteredFolders.isNotEmpty)
            ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              ),
              ..._filteredFolders.map((folder) => _buildFolderListItem(folder)).toList(),
              const Divider(height: 48),
            ],
          if (_filteredDocuments.isNotEmpty)
            ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              ),
              ..._filteredDocuments.map((doc) => _buildDocumentListItem(doc)).toList(),
            ],
        ],
      );
    }
  }
  
  Widget _buildFolderCard(Folder folder) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          _navigateToFolder(folder.id);
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
                        child: Row(
                          children: [
                            Icon(Icons.delete),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
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
        _navigateToFolder(folder.id);
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
              builder: (context) => DocumentViewerScreen(
                document: document,
              ),
            ),
          ).then((_) => _loadContent()); // Reload on navigation back
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive sizes based on available space
            final cardHeight = constraints.maxHeight;
            final cardWidth = constraints.maxWidth;
            final isSmallCard = cardHeight < 150 || cardWidth < 120;
            
            // Dynamic sizes based on card dimensions
            final iconSize = isSmallCard ? cardWidth * 0.2 : cardWidth * 0.25;
            final titleFontSize = isSmallCard ? 10.0 : 12.0;
            final subtitleFontSize = isSmallCard ? 8.0 : 10.0;
            final buttonSize = isSmallCard ? 18.0 : 22.0;
            final iconButtonSize = isSmallCard ? 16.0 : 20.0;
            final padding = isSmallCard ? 4.0 : 6.0;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flexible icon container - reduced space
                Flexible(
                  flex: 2, // Reduced from 3 to give more space to content
                  child: Container(
                    color: Colors.blue.shade100,
                    width: double.infinity,
                    child: Center(
                      child: Icon(
                        _getDocumentIconData(document),
                        size: iconSize.clamp(20.0, 50.0), // Responsive but within limits
                        color: _getDocumentIconColor(document),
                      ),
                    ),
                  ),
                ),
                // Flexible content area with much more space
                Flexible(
                  flex: 2, // Increased from 2 to 3 (60% of card space)
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title with much more space allocated
                        Expanded(
                          flex: 2, // Increased from 2 to 3 for more title space
                          child: Text(
                            document.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: titleFontSize,
                            ),
                            maxLines: isSmallCard ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: padding / 4),
                        // Subtitle with more space
                        Expanded(
                          flex: 1, // Increased from 1 to 2 for more date space
                          child: Text(
                            'Modified: ${document.updatedAt?.toString().split(' ')[0] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: padding / 4),
                        // Action buttons with minimal space
                        Expanded(
                          flex: 1, // Keep buttons minimal
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, size: iconButtonSize),
                                constraints: BoxConstraints(
                                  maxHeight: buttonSize,
                                  maxWidth: buttonSize,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  Navigator.push(
                                    context, 
                                    MaterialPageRoute(
                                      builder: (context) => DocumentViewerScreen(
                                        document: document,
                                      ),
                                    ),
                                  ).then((_) => _loadContent());
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.share, size: iconButtonSize),
                                constraints: BoxConstraints(
                                  maxHeight: buttonSize,
                                  maxWidth: buttonSize,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  _shareDocument(document);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.download, size: iconButtonSize),
                                constraints: BoxConstraints(
                                  maxHeight: buttonSize,
                                  maxWidth: buttonSize,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  _downloadDocument(document);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, size: iconButtonSize),
                                constraints: BoxConstraints(
                                  maxHeight: buttonSize,
                                  maxWidth: buttonSize,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  _deleteDocument(document);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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

  // Helper function to get icon data for flexible sizing
  IconData _getDocumentIconData(Document document) {
    switch (document.type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.csv:
        return Icons.table_chart;
      case DocumentType.docx:
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Helper function to get icon color
  Color _getDocumentIconColor(Document document) {
    switch (document.type) {
      case DocumentType.pdf:
        return Colors.red.shade800;
      case DocumentType.csv:
        return Colors.green.shade800;
      case DocumentType.docx:
        return Colors.blue.shade800;
      default:
        return Colors.blue.shade800;
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
                  builder: (context) => DocumentViewerScreen(
                    document: document,
                  ),
                ),
              ).then((_) => _loadContent());
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              _shareDocument(document);
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              _downloadDocument(document);
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
            builder: (context) => DocumentViewerScreen(
              document: document,
            ),
          ),
        ).then((_) => _loadContent());
      },
    );
  }
  
  void _onSearchChanged(String query) {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      _filterContent(query);
    });
  }

  void _filterContent(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFolders = _folders;
        _filteredDocuments = _documents;
      } else {
        final queryLower = query.toLowerCase();
        _filteredFolders = _folders.where((folder) {
          return folder.name.toLowerCase().contains(queryLower);
        }).toList();
        
        _filteredDocuments = _documents.where((document) {
          return document.name.toLowerCase().contains(queryLower);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _filterContent('');
  }

  void _handleBackNavigation() {
    if (widget.parentFolderId == null) {
      // We're at the root, PopScope will handle the exit
      return;
    }

    // Find the parent folder ID from the folder path
    String? parentFolderId;
    if (_folderPath.isNotEmpty) {
      // Get the parent of the current folder
      final currentFolderIndex = _folderPath.length - 1;
      if (currentFolderIndex > 0) {
        // Navigate to the parent folder
        parentFolderId = _folderPath[currentFolderIndex - 1].id;
      } else {
        // Navigate to root
        parentFolderId = null;
      }
    } else {
      // No folder path available, navigate to root
      parentFolderId = null;
    }

    _navigateToFolder(parentFolderId);
  }

  void _navigateToFolder(String? folderId) {
    if (folderId == null) {
      // Navigate to root - pop back to MainScreen instead of creating new stack
      Navigator.of(context).popUntil((route) => route.isFirst);
      // Trigger refresh after navigation is complete
      if (widget.onReturnToRoot != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onReturnToRoot!();
          }
        });
      }
      return;
    }
    
    // For non-root folders, use pushAndRemoveUntil to clear the stack
    // Create a new instance to ensure state is reset
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => FoldersScreen(
          parentFolderId: folderId,
          key: ValueKey('folder_$folderId'), // Unique key to ensure new instance
          onReturnToRoot: widget.onReturnToRoot, // Pass the callback down
        ),
      ),
      (route) => route.isFirst, // Keep the first route (MainScreen)
    );
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
                  close(context, folder.id);
                  // Navigate to the folder using the new method
                  if (folder.id == null) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  } else {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => FoldersScreen(
                          parentFolderId: folder.id,
                          key: ValueKey('folder_${folder.id}'), // Unique key to ensure new instance
                          onReturnToRoot: null, // No callback for search results
                        ),
                      ),
                      (route) => route.isFirst, // Keep the first route (MainScreen)
                    );
                  }
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

class _UploadFolderDialog extends StatefulWidget {
  final String? parentFolderId;
  final VoidCallback onFolderUploaded;

  const _UploadFolderDialog({
    this.parentFolderId,
    required this.onFolderUploaded,
  });

  @override
  State<_UploadFolderDialog> createState() => _UploadFolderDialogState();
}

class _UploadFolderDialogState extends State<_UploadFolderDialog> {
  final ApiService _apiService = ApiService();
  bool _isUploading = false;
  io.File? _selectedZipFile;
  List<int>? _selectedZipBytes;
  String? _selectedFileName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Folder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Compress your folder into a ZIP file\n'
              '2. Only PDF, DOCX, and CSV files will be imported\n'
              '3. Folder structure will be preserved\n'
              '4. Hidden and system files will be ignored',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // File selection button
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _selectZipFile,
              icon: const Icon(Icons.folder_zip),
              label: const Text('Select ZIP File'),
            ),
            
            if (_selectedFileName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected File:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(_selectedFileName!),
                          if (!kIsWeb && _selectedZipFile != null)
                            Text(
                              'Size: ${(FileUtils.lengthSync(_selectedZipFile!) / 1024 / 1024).toStringAsFixed(2)} MB',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isUploading || _selectedFileName == null) ? null : _uploadFolder,
          child: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Upload'),
        ),
      ],
    );
  }

  Future<void> _selectZipFile() async {
    try {
      developer.log('Starting file selection', name: 'FolderUpload');
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: kIsWeb, // Get bytes for web
      );

      if (result != null) {
        final pickedFile = result.files.single;
        developer.log('File selected: ${pickedFile.name}, size: ${pickedFile.size}', name: 'FolderUpload');
        
        if (kIsWeb) {
          // For web platform
          if (pickedFile.bytes == null) {
            developer.log('Error: No bytes available for web platform', name: 'FolderUpload');
            _showError('Could not read file data on web platform');
            return;
          }
          
          developer.log('Web platform: Setting bytes (${pickedFile.bytes!.length} bytes)', name: 'FolderUpload');
          setState(() {
            _selectedZipFile = null;
            _selectedZipBytes = pickedFile.bytes;
            _selectedFileName = pickedFile.name;
          });
        } else {
          // For other platforms
          if (pickedFile.path == null) {
            developer.log('Error: No path available for native platform', name: 'FolderUpload');
            _showError('Could not get file path');
            return;
          }
          
          developer.log('Native platform: Setting file path: ${pickedFile.path}', name: 'FolderUpload');
          setState(() {
            if (!kIsWeb) {
              io.File? newSelectedFile;
              if (!kIsWeb) {
                newSelectedFile = io.File(pickedFile.path!);
              }
              _selectedZipFile = newSelectedFile;
            } else {
              _selectedZipFile = null;
            }
            _selectedZipBytes = null;
            _selectedFileName = pickedFile.name;
          });
        }
        
        developer.log('File selection complete. File: ${_selectedFileName}, HasBytes: ${_selectedZipBytes != null}, HasFile: ${_selectedZipFile != null}', name: 'FolderUpload');
      } else {
        developer.log('No file selected by user', name: 'FolderUpload');
      }
    } catch (e) {
      developer.log('Error selecting file: $e', name: 'FolderUpload');
      _showError('Error selecting file: $e');
    }
  }

  Future<void> _uploadFolder() async {
    setState(() {
      _isUploading = true;
    });

    try {
      Map<String, dynamic> data = {};
      
      if (widget.parentFolderId != null) {
        data['parent'] = widget.parentFolderId;
      }

      dynamic response;
      
      developer.log('Starting folder upload with data: $data', name: 'FolderUpload');
      developer.log('Platform: ${kIsWeb ? "Web" : "Native"}', name: 'FolderUpload');
      
      if (kIsWeb && _selectedZipBytes != null) {
        // Web upload using bytes
        developer.log('Web upload: fileName=$_selectedFileName, size=${_selectedZipBytes!.length}', name: 'FolderUpload');
        response = await _apiService.uploadFileFromBytes(
          '/manager/folder/upload/',
          _selectedZipBytes!,
          _selectedFileName!,
          data.map((key, value) => MapEntry(key, value.toString())),
        );
      } else if (!kIsWeb && _selectedZipFile != null) {
        // Native platform upload using file
        developer.log('Native upload: filePath=${FileUtils.getFilePath(_selectedZipFile)}', name: 'FolderUpload');
        response = await _apiService.uploadFile(
          '/manager/folder/upload/',
          _selectedZipFile!,
          data.map((key, value) => MapEntry(key, value.toString())),
        );
      } else {
        throw Exception('No file selected or platform mismatch. Web: ${kIsWeb}, bytes: ${_selectedZipBytes != null}, file: ${_selectedZipFile != null}');
      }

      // Success
      Navigator.pop(context);
      widget.onFolderUploaded();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Folder uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class _ShareDialog extends StatefulWidget {
  final String documentId;
  final String documentName;

  const _ShareDialog({
    required this.documentId,
    required this.documentName,
  });

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final ApiService _apiService = ApiService();
  bool _isCreating = false;
  String? _shareLink;
  DateTime? _expiryDate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share Document'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document: ${widget.documentName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (_shareLink != null) ...[
              const Text('Share Link:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _shareLink!,
                        style: const TextStyle(fontSize: 12, color: Colors.black),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _shareLink!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Expiry date picker - only show when creating new link
            if (_shareLink == null) ...[
              Row(
                children: [
                  const Text('Expires: '),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _expiryDate = picked;
                        });
                      }
                    },
                    child: Text(
                      _expiryDate?.toString().split(' ')[0] ?? 'Select Date',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (_shareLink == null)
          ElevatedButton(
            onPressed: _isCreating ? null : _createShareLink,
            child: _isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Link'),
          ),
      ],
    );
  }

  Future<void> _createShareLink() async {
    setState(() {
      _isCreating = true;
    });

    try {
      final data = <String, dynamic>{
        'document': widget.documentId,
        'is_active': true,
      };

      if (_expiryDate != null) {
        data['expires_at'] = _expiryDate!.toIso8601String();
      }

      final response = await _apiService.post('/manager/share/', data, {});
      
      final token = response['token'];
      
      setState(() {
        _shareLink = '${API.baseUrl}/manager/share/$token/';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create share link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }
} 
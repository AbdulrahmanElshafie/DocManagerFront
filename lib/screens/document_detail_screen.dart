import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/document/document_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/blocs/document/document_state.dart';
import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/widgets/enhanced_document_editor.dart';
import 'package:doc_manager/widgets/document_actions.dart';
import 'package:doc_manager/shared/components/responsive_builder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DocumentDetailScreen extends StatefulWidget {
  final Document document;
  final bool isEditing;
  final bool isNewDocument;
  final String? initialTemplate;

  const DocumentDetailScreen({
    Key? key,
    required this.document,
    this.isEditing = false,
    this.isNewDocument = false,
    this.initialTemplate,
  }) : super(key: key);

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late DocumentBloc _documentBloc;
  bool _isEditing = false;
  bool _isLoading = true;
  String _errorMessage = '';
  File? _documentFile;
  final TextEditingController _nameController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _documentBloc = context.read<DocumentBloc>();
    _isEditing = widget.isEditing;
    _nameController.text = widget.document.name;
    _initializeDocument();
  }
  
  Future<void> _initializeDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // For new documents, we need to create the file on disk
      if (widget.isNewDocument) {
        await _createNewDocumentFile();
      } else if (widget.document.file != null) {
        // If the document has a file object already, use it
        _documentFile = widget.document.file!;
        setState(() {
          _isLoading = false;
        });
      } else if (widget.document.filePath != null && widget.document.filePath!.isNotEmpty) {
        // If the document has a file path, try to load the file
        try {
          // For web platform, we can't access files directly
          if (kIsWeb) {
            await _createNewDocumentFile();
            return;
          }
          
          String normalizedPath = widget.document.filePath!;
          
          // Normalize path for Windows if needed
          if (Platform.isWindows) {
            normalizedPath = normalizedPath.replaceAll('\\', '/');
          }
          
          // Check if the path is just "path" which can happen in error cases
          if (normalizedPath == "path" || normalizedPath.trim().isEmpty) {
            developer.log('Invalid file path detected: $normalizedPath', name: 'DocumentDetailScreen');
            await _createNewDocumentFile();
            return;
          }
          
          // Create file object but check existence safely
          final file = File(normalizedPath);
          developer.log('Checking if file exists at path: $normalizedPath', name: 'DocumentDetailScreen');
          
          bool fileExists = false;
          try {
            fileExists = await file.exists();
          } catch (e) {
            developer.log('Error checking if file exists: $e', name: 'DocumentDetailScreen');
          }
          
          if (fileExists) {
            _documentFile = file;
            setState(() {
              _isLoading = false;
            });
          } else {
            developer.log('File does not exist at normalized path: $normalizedPath', name: 'DocumentDetailScreen');
            // File doesn't exist, create a new one
            await _createNewDocumentFile();
          }
        } catch (pathError) {
          developer.log('Error with file path, creating new file instead: $pathError', name: 'DocumentDetailScreen');
          // If there's an issue with the path, create a new file
          await _createNewDocumentFile();
        }
      } else {
        // If no file or path, load document from server
        _documentBloc.add(LoadDocument(widget.document.id));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading document: $e';
        _isLoading = false;
      });
      developer.log('Error loading document: $e', name: 'DocumentDetailScreen');
    }
  }
  
  Future<void> _createNewDocumentFile() async {
    try {
      // For web platform, we handle differently
      if (kIsWeb) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final tempDir = await getTemporaryDirectory();
      
      // Create a file with appropriate extension based on document type
      String fileExtension;
      String initialContent = '';
      
      switch (widget.document.type) {
        case DocumentType.csv:
          fileExtension = '.csv';
          initialContent = 'Column1,Column2,Column3\nValue1,Value2,Value3';
          
          // Apply template if specified
          if (widget.initialTemplate != null) {
            switch (widget.initialTemplate) {
              case 'Contacts':
                initialContent = 'Name,Email,Phone\nJohn Doe,john@example.com,555-1234\nJane Smith,jane@example.com,555-5678';
                break;
              case 'Inventory':
                initialContent = 'Item,Quantity,Price\nProduct A,10,99.99\nProduct B,5,49.99';
                break;
              case 'Financial':
                initialContent = 'Date,Description,Amount\n2023-01-01,Income,1000.00\n2023-01-15,Expense,-50.00';
                break;
            }
          }
          break;
          
        case DocumentType.pdf:
          fileExtension = '.pdf';
          // Cannot easily create PDF content here, will use an empty PDF
          break;
          
        case DocumentType.docx:
          fileExtension = '.docx';
          initialContent = 'Document content goes here.';
          
          // Apply template if specified
          if (widget.initialTemplate != null) {
            switch (widget.initialTemplate) {
              case 'Letter':
                initialContent = 'Dear [Recipient],\n\nI am writing to...\n\nSincerely,\n[Your Name]';
                break;
              case 'Resume':
                initialContent = 'RESUME\n\nNAME: [Your Name]\nEMAIL: [your.email@example.com]\nPHONE: [Your Phone]\n\nEXPERIENCE\n[Company Name] - [Position]\n[Start Date] - [End Date]\n• [Achievement/Responsibility]\n• [Achievement/Responsibility]\n\nEDUCATION\n[Degree] in [Field] - [Institution]\n[Year]';
                break;
              case 'Meeting Minutes':
                initialContent = 'MEETING MINUTES\n\nDate: [Date]\nTime: [Time]\nLocation: [Location]\n\nAttendees:\n• [Person 1]\n• [Person 2]\n\nAgenda Items:\n1. [Item 1]\n2. [Item 2]\n\nDiscussion:\n[Notes]\n\nAction Items:\n• [Action 1] - Assigned to: [Person] - Due: [Date]\n• [Action 2] - Assigned to: [Person] - Due: [Date]';
                break;
            }
          }
          break;
          
        case DocumentType.unsupported:
        default:
          fileExtension = '.txt';
          initialContent = 'Document content goes here.';
      }
      
      // Ensure filename has correct extension
      String fileName = widget.document.name;
      if (!fileName.toLowerCase().endsWith(fileExtension)) {
        fileName = '$fileName$fileExtension';
      }

      String safeFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      try {
        // Create the file
        String filePath = '${tempDir.path}/$safeFileName';
        // Use path.normalize to ensure correct path format for Windows
        filePath = path.normalize(filePath);
        
        final file = File(filePath);
        developer.log('Creating new file at: $filePath', name: 'DocumentDetailScreen');
        
        // For PDF, we can't easily create content here
        // For other types, write the initial content
        if (widget.document.type != DocumentType.pdf) {
          await file.writeAsString(initialContent);
        } else {
          // Create an empty file for PDF
          await file.writeAsBytes([]);
        }
        
        // Check if file was created successfully
        if (await file.exists()) {
          developer.log('File created successfully at: $filePath', name: 'DocumentDetailScreen');
          _documentFile = file;
        } else {
          throw Exception('Failed to create file at: $filePath');
        }
      } catch (fileError) {
        developer.log('Error creating file: $fileError', name: 'DocumentDetailScreen');
        throw Exception('Error creating file: $fileError');
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Don't show the error to the user if it's related to getTemporaryDirectory
      if (e.toString().contains('getTemporaryDirectory') && kIsWeb) {
        developer.log('Web platform does not support getTemporaryDirectory, continuing without file: $e', 
          name: 'DocumentDetailScreen');
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error creating document: $e';
          _isLoading = false;
        });
        developer.log('Error creating new document file: $e', name: 'DocumentDetailScreen');
      }
    }
  }
  
  Future<void> _handleSaveDocument(File updatedFile) async {
    try {
      final fileName = path.basename(updatedFile.path);
      
      // Update name controller if file name changed
      if (fileName != _nameController.text && !_nameController.text.contains(path.extension(fileName))) {
        _nameController.text = fileName;
      }
      
      // Only save to backend if not a new document or if we're ready to create it
      if (!widget.isNewDocument) {
        _documentBloc.add(UpdateDocument(
          id: widget.document.id,
          file: updatedFile,
          name: _nameController.text,
          folderId: widget.document.folderId,
        ));
      }
      
      setState(() {
        _documentFile = updatedFile;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document updated successfully')),
      );
    } catch (e) {
      developer.log('Error saving document: $e', name: 'DocumentDetailScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save document: $e')),
      );
    }
  }
  
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }
  
  void _saveDocument() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document name cannot be empty')),
      );
      return;
    }

    try {
      // Special handling for web platform
      if (kIsWeb) {
        // For web, we use a simplified approach without actual files
        if (widget.isNewDocument) {
          // Create a document with just text content
          _documentBloc.add(CreateDocument(
            name: _nameController.text,
            folderId: widget.document.folderId,
            content: "Web document content for ${_nameController.text}",
          ));
        } else {
          // Update existing document
          _documentBloc.add(UpdateDocument(
            id: widget.document.id,
            name: _nameController.text,
            folderId: widget.document.folderId,
            content: "Updated web document content for ${_nameController.text}",
          ));
        }
      } else {
        // Native platform handling with actual files
        if (_documentFile == null) {
          throw Exception("No document file available");
        }
        
        if (widget.isNewDocument) {
          // If it's a new document, create it on the server
          _documentBloc.add(AddDocument(
            file: _documentFile!,
            name: _nameController.text,
            folderId: widget.document.folderId,
          ));
        } else {
          // If it's an existing document, update it
          _documentBloc.add(UpdateDocument(
            id: widget.document.id,
            file: _documentFile!,
            name: _nameController.text,
            folderId: widget.document.folderId,
          ));
        }
      }
      
      // If we were in edit mode, exit it
      if (_isEditing) {
        setState(() {
          _isEditing = false;
        });
      }
    } catch (e) {
      developer.log('Error saving document: $e', name: 'DocumentDetailScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save document: $e')),
      );
    }
  }
  
  void _deleteDocument() {
    _documentBloc.add(DeleteDocument(
      widget.document.id,
      folderId: widget.document.folderId,
    ));
    Navigator.pop(context);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNewDocument ? 'Create Document' : 'Document Details'),
        actions: [
          // Edit button
          if (!_isEditing && !widget.isNewDocument)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEditMode,
              tooltip: 'Edit',
            ),
          // Save button
          if (_isEditing || widget.isNewDocument)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveDocument,
              tooltip: 'Save',
            ),
          // Cancel edit button
          if (_isEditing && !widget.isNewDocument)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _toggleEditMode,
              tooltip: 'Cancel',
            ),
        ],
      ),
      body: BlocConsumer<DocumentBloc, DocumentState>(
        listener: (context, state) {
          if (state is DocumentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error)),
            );
          } else if (state is DocumentOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            
            // If we successfully created or updated a document, and it's a new document, go back
            if (widget.isNewDocument && (state is DocumentCreated || state is DocumentUpdated)) {
              Navigator.pop(context);
            }
          } else if (state is DocumentLoaded && _isLoading) {
            // If we received a document from the server, use its file path if available
            if (state.document.file != null) {
              setState(() {
                _documentFile = state.document.file!;
                _isLoading = false;
              });
            } else if (state.document.filePath != null && state.document.filePath!.isNotEmpty) {
              final file = File(state.document.filePath!);
              setState(() {
                _documentFile = file;
                _isLoading = false;
              });
            } else {
              setState(() {
                _errorMessage = 'Document has no file';
                _isLoading = false;
              });
            }
          }
        },
        builder: (context, state) {
          if (state is DocumentLoading || _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (_errorMessage.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeDocument,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          return ResponsiveBuilder(
            mobile: _buildMobileLayout(),
            tablet: _buildTabletLayout(),
            desktop: _buildDesktopLayout(),
          );
        },
      ),
    );
  }
  
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildDocumentHeader(),
        Expanded(
          child: _buildDocumentContent(),
        ),
      ],
    );
  }
  
  Widget _buildTabletLayout() {
    return Column(
      children: [
        _buildDocumentHeader(),
        Expanded(
          child: _buildDocumentContent(),
        ),
      ],
    );
  }
  
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Side panel with details and actions (1/3 of width)
        SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDocumentHeader(),
                const SizedBox(height: 20),
                DocumentActions(
                  document: widget.document,
                  onEdit: _toggleEditMode,
                  onDelete: _deleteDocument,
                ),
              ],
            ),
          ),
        ),
        
        // Document content (2/3 of width)
        Expanded(
          flex: 2,
          child: _buildDocumentContent(),
        ),
      ],
    );
  }
  
  Widget _buildDocumentHeader() {
    // Get appropriate icon and color based on document type
    IconData iconData;
    Color iconColor;
    
    switch (widget.document.type) {
      case DocumentType.pdf:
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red.shade700;
        break;
      case DocumentType.docx:
        iconData = Icons.description;
        iconColor = Colors.blue.shade700;
        break;
      case DocumentType.csv:
        iconData = Icons.table_chart;
        iconColor = Colors.green.shade700;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey.shade700;
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, color: iconColor, size: 36),
                const SizedBox(width: 12),
                _isEditing || widget.isNewDocument
                  ? Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Document Name',
                        ),
                      ),
                    )
                  : Expanded(
                      child: Text(
                        widget.document.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
            ),
            const Divider(),
            Text(
              'Type: ${widget.document.type.toString().split('.').last.toUpperCase()}',
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Created: ${widget.document.createdAt.toString().split('.')[0]}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (widget.document.updatedAt != null)
              Text(
                'Last modified: ${widget.document.updatedAt!.toString().split('.')[0]}',
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDocumentContent() {
    // In mobile or tablet layout, add some padding
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    return Padding(
      padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.all(16.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: kIsWeb || _documentFile == null
            ? _buildWebDocumentEditor()
            : EnhancedDocumentEditor(
                file: _documentFile!,
                documentType: widget.document.type,
                documentName: widget.document.name,
                readOnly: !_isEditing && !widget.isNewDocument,
                onSave: _handleSaveDocument,
              ),
      ),
    );
  }
  
  // Special editor for web platform or when file is null
  Widget _buildWebDocumentEditor() {
    switch (widget.document.type) {
      case DocumentType.pdf:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf, size: 72, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'PDF viewing is limited in this environment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.document.name,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Document viewing is limited in this environment.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case DocumentType.csv:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.table_chart, size: 72, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Spreadsheet Viewer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.document.name,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (_isEditing)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Spreadsheet Content (Web View)',
                      hintText: 'Spreadsheet editing is limited in this environment.',
                    ),
                    maxLines: 10,
                  ),
                ),
            ],
          ),
        );
      case DocumentType.docx:
      default:
        // Text editor as fallback
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.description, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                widget.document.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _nameController, // Reuse the name controller as a simple text editor
                  readOnly: !_isEditing && !widget.isNewDocument,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Document content goes here.\n\nEdit this document.',
                  ),
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
                ),
              ),
            ],
          ),
        );
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

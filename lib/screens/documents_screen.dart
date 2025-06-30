import 'dart:io' as io show File;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';

import '../models/document.dart';
import '../blocs/document/document_bloc.dart';
import '../blocs/document/document_state.dart';
import '../blocs/folder/folder_bloc.dart';
import '../blocs/folder/folder_event.dart';
import '../blocs/folder/folder_state.dart';
import '../widgets/unified_document_viewer.dart';
import '../widgets/document_actions.dart';
import '../widgets/metadata_section.dart';
import '../widgets/versions_section.dart';
import '../widgets/comments_section.dart';
import '../shared/components/responsive_builder.dart';
import '../shared/network/api_service.dart';
import '../shared/utils/logger.dart';

class DocumentsScreen extends StatefulWidget {
  final String? folderId;
  final String? initialQuery;

  const DocumentsScreen({
    super.key,
    this.folderId,
    this.initialQuery,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFolderId;
  Document? _selectedDocument;
  String _viewMode = 'grid'; // 'grid' or 'list'
  String _sortBy = 'name'; // 'name', 'date', 'type'
  Timer? _searchDebouncer;
  
  // Tab controller for document details
  late TabController _tabController;

  List<Document> _documents = [];
  List<Document> _filteredDocuments = [];

  // Resizable details panel width
  double _detailsPanelWidth = 400.0;
  final double _minDetailsPanelWidth = 300.0;
  final double _maxDetailsPanelWidth = 500.0;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.folderId;
    _searchController.text = widget.initialQuery ?? '';
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize filtered documents
    _filteredDocuments = _documents;
    
    // Load initial data
    _loadDocuments();
    
    // Load folders for folder selector
    context.read<FolderBloc>().add(const LoadFolders());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            onPressed: _showFileUploadOptions,
            icon: const Icon(Icons.add),
            tooltip: 'Add Document',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'view_mode':
                  _toggleViewMode();
                  break;
                case 'sort':
                  _showSortOptions();
                  break;
                case 'create_new':
                  _showCreateNewDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'view_mode',
                child: Row(
                  children: [
                    Icon(_viewMode == 'grid' ? Icons.list : Icons.grid_view),
                    const SizedBox(width: 8),
                    Text(_viewMode == 'grid' ? 'List View' : 'Grid View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    Icon(Icons.sort),
                    SizedBox(width: 8),
                    Text('Sort'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'create_new',
                child: Row(
                  children: [
                    Icon(Icons.create_new_folder),
                    SizedBox(width: 8),
                    Text('Create New'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(child: _buildDocumentsList()),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          _buildViewModeToggle(),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showCreateNewDialog,
            icon: const Icon(Icons.create_new_folder),
            label: const Text('Create New'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showFileUploadOptions,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildDocumentsList(),
                ),
                if (_selectedDocument != null) ...[
                  _buildResizeHandle(),
                  Container(
                    width: _detailsPanelWidth,
                    child: _buildDocumentDetails(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          _buildViewModeToggle(),
          const SizedBox(width: 16),
          _buildSortDropdown(),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _showCreateNewDialog,
            icon: const Icon(Icons.create_new_folder),
            label: const Text('Create New'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showFileUploadOptions,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildDocumentsList(),
                ),
                if (_selectedDocument != null) ...[
                  _buildResizeHandle(),
                  Container(
                    width: _detailsPanelWidth,
                    child: _buildDocumentDetails(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search documents...',
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
                  onSubmitted: _onSearchSubmitted,
                ),
              ),
              const SizedBox(width: 16),
              _buildFolderSelector(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFolderSelector() {
    return BlocBuilder<FolderBloc, FolderState>(
      builder: (context, state) {
        if (state is FoldersLoaded) {
          return DropdownButton<String?>(
            value: _selectedFolderId,
            hint: const Text('All Folders'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Folders'),
              ),
              ...state.folders.map((folder) => DropdownMenuItem<String?>(
                value: folder.id,
                child: Text(folder.name),
              )),
            ],
            onChanged: (String? folderId) {
              setState(() {
                _selectedFolderId = folderId;
              });
              _loadDocuments();
            },
          );
        }
        return const CircularProgressIndicator();
      },
    );
  }

  Widget _buildViewModeToggle() {
    return ToggleButtons(
      isSelected: [_viewMode == 'grid', _viewMode == 'list'],
      onPressed: (index) {
        setState(() {
          _viewMode = index == 0 ? 'grid' : 'list';
        });
      },
      children: const [
        Icon(Icons.grid_view),
        Icon(Icons.list),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return DropdownButton<String>(
      value: _sortBy,
      items: const [
        DropdownMenuItem(value: 'name', child: Text('Sort by Name')),
        DropdownMenuItem(value: 'date', child: Text('Sort by Date')),
        DropdownMenuItem(value: 'type', child: Text('Sort by Type')),
      ],
      onChanged: (String? value) {
        if (value != null) {
          setState(() {
            _sortBy = value;
          });
        }
      },
    );
  }

  Widget _buildDocumentsList() {
    return BlocListener<DocumentBloc, DocumentState>(
      listener: (context, state) {
        if (state is DocumentOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is DocumentError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: BlocBuilder<DocumentBloc, DocumentState>(
        builder: (context, state) {
          if (state is DocumentsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DocumentsLoaded) {
            final sortedDocuments = _sortDocuments(_filteredDocuments);
            
            if (sortedDocuments.isEmpty) {
              return _buildEmptyState();
            }

            return _viewMode == 'grid'
                ? _buildGridView(sortedDocuments)
                : _buildListView(sortedDocuments);
          } else if (state is DocumentError) {
            return _buildErrorState(state.error);
          }
          return _buildEmptyState();
        },
      ),
    );
  }

  Widget _buildGridView(List<Document> documents) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        return _buildDocumentCard(document);
      },
    );
  }

  Widget _buildListView(List<Document> documents) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        return _buildDocumentListTile(document);
      },
    );
  }

  Widget _buildDocumentCard(Document document) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _selectDocument(document),
        onDoubleTap: () => _openDocument(document),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _getDocumentTypeColor(document.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getDocumentTypeIcon(document.type),
                    size: 48,
                    color: _getDocumentTypeColor(document.type),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                document.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatDocumentType(document.type),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getDocumentTypeColor(document.type),
                ),
              ),
              Text(
                _formatDate(document.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentListTile(Document document) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _selectDocument(document),
        onDoubleTap: () => _openDocument(document),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getDocumentTypeColor(document.type).withValues(alpha: 0.1),
            child: Icon(
              _getDocumentTypeIcon(document.type),
              color: _getDocumentTypeColor(document.type),
            ),
          ),
          title: Text(
            document.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDocumentType(document.type)),
              Text(_formatDate(document.createdAt)),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleDocumentAction(document, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'open', child: Text('Open')),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'download', child: Text('Download')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          selected: _selectedDocument?.id == document.id,
        ),
      ),
    );
  }

  Widget _buildResizeHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _detailsPanelWidth = (_detailsPanelWidth - details.delta.dx)
                .clamp(_minDetailsPanelWidth, _maxDetailsPanelWidth);
          });
        },
        child: Container(
          width: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            border: Border(
              left: BorderSide(color: Colors.grey.shade400, width: 1),
              right: BorderSide(color: Colors.grey.shade400, width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 1,
                height: 20,
                color: Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Container(
                width: 1,
                height: 20,
                color: Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Container(
                width: 1,
                height: 20,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentDetails() {
    if (_selectedDocument == null) {
      return const Center(
        child: Text('Select a document to view details'),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedDocument!.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openDocument(_selectedDocument!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open'),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Details'),
            Tab(icon: Icon(Icons.history), text: 'Versions'),
            Tab(icon: Icon(Icons.comment), text: 'Comments'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Details Tab (Actions and Metadata)
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _detailsPanelWidth,
                    minWidth: _detailsPanelWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: _detailsPanelWidth),
                        child: DocumentActions(
                          document: _selectedDocument!,
                          onEdit: () => _openDocument(_selectedDocument!),
                          onDelete: () => _showDeleteConfirmation(_selectedDocument!),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: _detailsPanelWidth),
                        child: MetadataSection(document: _selectedDocument!),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Versions Tab
              Container(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _detailsPanelWidth),
                  child: VersionsSection(documentId: _selectedDocument!.id),
                ),
              ),
              
              // Comments Tab
              Container(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _detailsPanelWidth),
                  child: CommentsSection(documentId: _selectedDocument!.id),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty 
                ? 'No documents found' 
                : 'No documents in this folder',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty 
                ? 'Try a different search term'
                : 'Upload a document or create a new one to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_searchController.text.isEmpty)
            ElevatedButton.icon(
              onPressed: _showFileUploadOptions,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Document'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading documents',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDocuments,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  void _selectDocument(Document document) {
    setState(() {
      _selectedDocument = document;
    });
  }

  void _openDocument(Document document) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UnifiedDocumentViewer(
          document: document,
          onDocumentUpdated: () {
            // Refresh the documents list when document is updated
            _loadDocuments();
          },
        ),
      ),
    );
  }

  void _handleDocumentAction(Document document, String action) {
    switch (action) {
      case 'open':
        _openDocument(document);
        break;
      case 'edit':
        _openDocument(document);
        break;
      case 'download':
        // Implement download functionality
        break;
      case 'delete':
        _showDeleteConfirmation(document);
        break;
    }
  }

  void _showDeleteConfirmation(Document document) {
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
              _apiService.deleteDocument(document.id, document.folderId);
              if (_selectedDocument?.id == document.id) {
                setState(() {
                  _selectedDocument = null;
                });
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFileUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('Upload from Device'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('Create New Document'),
              onTap: () {
                Navigator.pop(context);
                _showCreateNewDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateNewDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateDocumentDialog(
        folderId: _selectedFolderId,
        onDocumentCreated: () {
          _loadDocuments();
        },
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'csv', 'docx', 'doc'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null && !kIsWeb) {
        io.File? file;
        if (!kIsWeb) {
          file = io.File(result.files.single.path!);
        }
        final fileName = result.files.single.name;

        _apiService.addDocument(
          _selectedFolderId,
          file,
          fileName,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadDocuments() async {
    try {
      Map<String, dynamic> params = {};
      
      // Add folder filter if specified
      if (_selectedFolderId != null) {
        params['folder'] = _selectedFolderId!;
      }
      
      final response = await _apiService.getList('/manager/document/', params);
      
      List<Document> documents = response.map((doc) => Document.fromJson(doc)).toList();
      
      setState(() {
        _documents = documents;
      });
      
      // Apply current search filter
      _filterDocuments(_searchController.text);
    } catch (e) {
      LoggerUtil.error('Error loading documents: $e');
    }
  }

  void _onSearchChanged(String query) {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      _filterDocuments(query);
    });
  }

  void _onSearchSubmitted(String query) {
    _searchDebouncer?.cancel();
    _filterDocuments(query);
  }

  void _clearSearch() {
    _searchController.clear();
    _filterDocuments('');
  }

  void _filterDocuments(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredDocuments = _documents;
      } else {
        final queryLower = query.toLowerCase();
        _filteredDocuments = _documents.where((document) {
          return document.name.toLowerCase().contains(queryLower);
        }).toList();
      }
    });
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == 'grid' ? 'list' : 'grid';
    });
  }

  void _showSortOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Documents'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Name'),
              value: 'name',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Date'),
              value: 'date',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Type'),
              value: 'type',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Document> _sortDocuments(List<Document> documents) {
    final sorted = List<Document>.from(documents);
    
    switch (_sortBy) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'date':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'type':
        sorted.sort((a, b) => a.type.toString().compareTo(b.type.toString()));
        break;
    }
    
    return sorted;
  }

  IconData _getDocumentTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.csv:
        return Icons.table_chart;
      case DocumentType.docx:
        return Icons.description;
      case DocumentType.unsupported:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Colors.red;
      case DocumentType.csv:
        return Colors.green;
      case DocumentType.docx:
        return Colors.blue;
      case DocumentType.unsupported:
        return Colors.grey;
    }
  }

  String _formatDocumentType(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return 'PDF Document';
      case DocumentType.csv:
        return 'CSV Spreadsheet';
      case DocumentType.docx:
        return 'Word Document';
      case DocumentType.unsupported:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _CreateDocumentDialog extends StatefulWidget {
  final String? folderId;
  final VoidCallback onDocumentCreated;

  const _CreateDocumentDialog({
    this.folderId,
    required this.onDocumentCreated,
  });

  @override
  State<_CreateDocumentDialog> createState() => _CreateDocumentDialogState();
}

class _CreateDocumentDialogState extends State<_CreateDocumentDialog> {
  final TextEditingController _nameController = TextEditingController();
  final ApiService _apiService = ApiService();
  DocumentType _selectedType = DocumentType.pdf;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Document'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Document Name',
              hintText: 'Enter document name',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          const Text('Document Type:'),
          const SizedBox(height: 8),
          DropdownButtonFormField<DocumentType>(
            value: _selectedType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: DocumentType.pdf,
                child: Text('PDF Document'),
              ),
              DropdownMenuItem(
                value: DocumentType.csv,
                child: Text('CSV Spreadsheet'),
              ),
              DropdownMenuItem(
                value: DocumentType.docx,
                child: Text('Word Document'),
              ),
            ],
            onChanged: (DocumentType? value) {
              if (value != null) {
                setState(() {
                  _selectedType = value;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createDocument,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createDocument() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a document name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Add appropriate file extension if not present
      String fileName = _nameController.text.trim();
      final extension = _getFileExtension(_selectedType);
      if (!fileName.toLowerCase().endsWith(extension)) {
        fileName += extension;
      }

      // Create initial content based on type
      String initialContent = _getInitialContent(_selectedType);

      // Use the content-based document creation method instead of File
      await _apiService.createContentDocument(
        name: fileName,
        folderId: widget.folderId,
        content: initialContent,
      );

      Navigator.pop(context);
      widget.onDocumentCreated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  String _getFileExtension(DocumentType type) {
    switch (type) {
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

  String _getInitialContent(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return 'This is a new PDF document.';
      case DocumentType.csv:
        return 'Column 1,Column 2,Column 3\nValue 1,Value 2,Value 3';
      case DocumentType.docx:
        return 'This is a new Word document.\n\nStart typing here...';
      case DocumentType.unsupported:
        return 'New document content';
    }
  }
}

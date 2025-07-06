import 'dart:io' as io show File;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/document.dart';
import '../models/folder.dart';
import '../models/shareable_link.dart';
import '../blocs/document/document_bloc.dart';
import '../blocs/document/document_event.dart';
import '../blocs/document/document_state.dart';
import '../blocs/folder/folder_bloc.dart';
import '../blocs/folder/folder_event.dart';
import '../blocs/folder/folder_state.dart';
import '../blocs/activity_log/activity_log_bloc.dart';
import '../blocs/activity_log/activity_log_event.dart';
import '../blocs/activity_log/activity_log_state.dart';
import '../blocs/comment/comment_bloc.dart';
import '../blocs/comment/comment_event.dart';
import '../blocs/comment/comment_state.dart';
import '../blocs/version/version_bloc.dart';
import '../blocs/version/version_event.dart';
import '../blocs/version/version_state.dart';
import '../models/activity_log.dart';
import '../models/comment.dart';
import '../models/version.dart';
import '../screens/document_viewer_screen.dart';
import '../repository/shareable_link_repository.dart';
import '../shared/components/responsive_builder.dart';
import '../shared/network/api_service.dart';
import '../shared/network/api.dart';
import '../shared/utils/web_download_helper_stub.dart'
    if (dart.library.html) '../shared/utils/web_download_helper.dart';

// Helper class to hold activity colors
class ActivityColors {
  final Color primary;
  final Color background;
  final IconData icon;

  const ActivityColors({
    required this.primary,
    required this.background,
    required this.icon,
  });
}

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

  // Resizable details panel width
  double _detailsPanelWidth = 400.0;
  double get _minDetailsPanelWidth => ResponsiveBuilder.isMobile(context) ? 280.0 : 300.0;
  double get _maxDetailsPanelWidth => ResponsiveBuilder.isMobile(context) ? 350.0 : 500.0;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.folderId;
    _searchController.text = widget.initialQuery ?? '';
    _tabController = TabController(length: 6, vsync: this);
    
    // Load initial data
    context.read<DocumentBloc>().add(LoadDocuments(folderId: _selectedFolderId));
    context.read<FolderBloc>().add(const LoadFolders());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set responsive panel width
    final isMobile = ResponsiveBuilder.isMobile(context);
    _detailsPanelWidth = isMobile ? 320.0 : 400.0;
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
                  SizedBox(
                    width: _detailsPanelWidth.clamp(_minDetailsPanelWidth, _maxDetailsPanelWidth),
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
                  SizedBox(
                    width: _detailsPanelWidth.clamp(_minDetailsPanelWidth, _maxDetailsPanelWidth),
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
              context.read<DocumentBloc>().add(LoadDocuments(folderId: folderId));
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
          // No need to reload - the DocumentBloc should handle state updates internally
          // This provides better performance by avoiding unnecessary API calls
        } else if (state is DocumentDeletedWithList) {
          // Handle optimized delete success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is DocumentCreatedWithList) {
          // Handle document creation success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is DocumentUpdatedWithList) {
          // Handle document update success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document updated successfully'),
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
            // Handle normal document loading
            final docs = state.documents;
            return _buildDocumentGrid(docs);
          } else if (state is DocumentDeletedWithList) {
            // Handle optimized delete state - show updated list immediately
            final docs = state.documents ?? [];
            return _buildDocumentGrid(docs);
          } else if (state is DocumentCreatedWithList) {
            // Handle document creation with updated list
            final docs = state.documents;
            return _buildDocumentGrid(docs);
          } else if (state is DocumentUpdatedWithList) {
            // Handle document update with updated list
            final docs = state.documents ?? [];
            return _buildDocumentGrid(docs);
          } else if (state is DocumentError) {
            return _buildErrorState(state.error);
          }
          return _buildEmptyState();
        },
      ),
    );
  }

  // Helper method to build document grid/list with filtering and sorting
  Widget _buildDocumentGrid(List<Document> documents) {
    // 1) Locally filter documents by search query
    final filtered = _searchController.text.isEmpty
        ? documents
        : documents.where((d) =>
            d.name.toLowerCase().contains(_searchController.text.toLowerCase())
          ).toList();
    
    // 2) Sort the filtered list
    final sorted = _sortDocuments(filtered);

    if (sorted.isEmpty) {
      return _buildEmptyState();
    }

    // 3) Return appropriate view based on view mode
    return _viewMode == 'grid'
        ? _buildGridView(sorted)
        : _buildListView(sorted);
  }

  Widget _buildGridView(List<Document> documents) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveBuilder.isDesktop(context) ? 5 : 
                      ResponsiveBuilder.isTablet(context) ? 4 : 2,
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
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          selected: _selectedDocument?.id == document.id,
        onTap: () => _selectDocument(document),
      ),
    );
  }

  Widget _buildResizeHandle() {
    final colorScheme = Theme.of(context).colorScheme;
    
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
            color: colorScheme.surfaceVariant,
            border: Border(
              left: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5), width: 1),
              right: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5), width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 1,
                height: 20,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 4),
              Container(
                width: 1,
                height: 20,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 4),
              Container(
                width: 1,
                height: 20,
                color: colorScheme.outline,
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

    final isMobile = ResponsiveBuilder.isMobile(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Header section with document name and open button
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedDocument!.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: isMobile ? 16 : 18,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
              ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openDocument(_selectedDocument!),
                icon: Icon(Icons.open_in_new, size: isMobile ? 16 : 18),
                label: Text(isMobile ? 'Open' : 'Open'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: isMobile ? 4 : 8,
                  ),
                  textStyle: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Close detail tab',
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDocument = null;
                    });
                  },
                  icon: Icon(
                    Icons.close,
                    size: isMobile ? 20 : 24,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.all(isMobile ? 4 : 8),
                    minimumSize: Size(isMobile ? 32 : 40, isMobile ? 32 : 40),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Tab bar with responsive sizing
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor,
              ),
            ),
          ),
          child: TabBar(
          controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: TextStyle(fontSize: isMobile ? 11 : 13),
            unselectedLabelStyle: TextStyle(fontSize: isMobile ? 11 : 13),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
            tabs: [
              Tab(
                icon: Icon(Icons.info, size: isMobile ? 16 : 20),
                text: 'Details',
                height: isMobile ? 60 : 72,
              ),
              Tab(
                icon: Icon(Icons.settings, size: isMobile ? 16 : 20),
                text: 'Actions',
                height: isMobile ? 60 : 72,
              ),
              Tab(
                icon: Icon(Icons.comment, size: isMobile ? 16 : 20),
                text: 'Comments',
                height: isMobile ? 60 : 72,
              ),
              Tab(
                icon: Icon(Icons.layers, size: isMobile ? 16 : 20),
                text: 'Versions',
                height: isMobile ? 60 : 72,
              ),
              Tab(
                icon: Icon(Icons.analytics, size: isMobile ? 16 : 20),
                text: 'Analysis',
                height: isMobile ? 60 : 72,
              ),
              Tab(
                icon: Icon(Icons.history, size: isMobile ? 16 : 20),
                text: 'Activity',
                height: isMobile ? 60 : 72,
              ),
            ],
          ),
        ),
        
        // Tab content with constrained height
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Details Tab
              _buildTabContent(_buildDocumentDetailsContent()),
              
              // Actions Tab
              _buildTabContent(_buildDocumentActionsContent()),
              
              // Comments Tab
              _buildTabContent(_buildDocumentCommentsContent()),
              
              // Versions Tab
              _buildTabContent(_buildDocumentVersionsContent()),
              
              // Analysis Tab  
              _buildTabContent(_buildDocumentAnalysisContent()),
              
              // Activity Tab
              _buildTabContent(_buildDocumentActivityContent()),      
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to wrap tab content with proper scrolling and responsive padding
  Widget _buildTabContent(Widget content) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
              minHeight: constraints.maxHeight - (isMobile ? 24 : 32),
            ),
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildDocumentDetailsContent() {
    if (_selectedDocument == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailRow('Name', _selectedDocument!.name),
        _buildDetailRow('Type', _formatDocumentType(_selectedDocument!.type)),
        _buildDetailRow('ID', _selectedDocument!.id),
        _buildDetailRow('Created', _formatDate(_selectedDocument!.createdAt)),
        if (_selectedDocument!.updatedAt != null)
          _buildDetailRow('Updated', _formatDate(_selectedDocument!.updatedAt!)),
        if (_selectedDocument!.folderId.isNotEmpty)
          _buildDetailRow('Folder', _getFolderDisplayName(_selectedDocument!.folderId)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final theme = Theme.of(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 70 : 80,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isMobile ? 12 : 14,
              ),
              maxLines: isMobile ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildDocumentAnalysisContent() {
    if (_selectedDocument == null) return const SizedBox();

    final isMobile = ResponsiveBuilder.isMobile(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          // Document Statistics Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics, color: colorScheme.primary),
                      SizedBox(width: isMobile ? 6 : 8),
                      Flexible(
                        child: Text(
                          'Document Statistics',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: isMobile ? 16 : 20,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildDocumentStatsGrid(),
                ],
              ),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          
          // Recent Activity Summary Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timeline, color: colorScheme.primary),
                      SizedBox(width: isMobile ? 6 : 8),
                      Flexible(
                        child: Text(
                          'Recent Activity Summary',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: isMobile ? 16 : 20,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildRecentActivitySummary(),
                ],
              ),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          
          // Document Properties Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary),
                      SizedBox(width: isMobile ? 6 : 8),
                      Flexible(
                        child: Text(
                          'Document Properties',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: isMobile ? 16 : 20,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildAnalysisMetric('Document Type', _formatDocumentType(_selectedDocument!.type)),
                  _buildAnalysisMetric('Created', _formatDate(_selectedDocument!.createdAt)),
                  _buildAnalysisMetric('Last Modified', _selectedDocument!.updatedAt != null 
                      ? _formatDate(_selectedDocument!.updatedAt!) 
                      : 'Never'),
                  _buildAnalysisMetric('Owner', _getOwnerDisplayName()),
                  _buildAnalysisMetric('Security Level', _getSecurityLevel(_selectedDocument!)),
                ],
              ),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          
          // Content Analysis Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: colorScheme.primary),
                      SizedBox(width: isMobile ? 6 : 8),
                      Flexible(
                        child: Text(
                          'Content Analysis',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: isMobile ? 16 : 20,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  Text(
                    _getContentSummary(_selectedDocument!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentActivityContent() {
    if (_selectedDocument == null) return const SizedBox();

    return BlocBuilder<ActivityLogBloc, ActivityLogState>(
      builder: (context, state) {
        if (state is ActivityLogsLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ActivityLogsLoaded) {
          final activities = state.activityLogs;
          if (activities.isEmpty) {
            return const Center(
              child: Text('No activity recorded for this document.'),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: activities.map((activity) => _buildActivityItem(activity)).toList(),
          );
        } else if (state is ActivityLogError) {
          return Center(
            child: Text('Error loading activity: ${state.error}'),
          );
        }
        return const Center(child: Text('No activity data available.'));
      },
    );
  }

  Widget _buildDocumentCommentsContent() {
    if (_selectedDocument == null) return const SizedBox();

    final isMobile = ResponsiveBuilder.isMobile(context);
    final theme = Theme.of(context);

    return BlocBuilder<CommentBloc, CommentState>(
      builder: (context, state) {
        if (state is CommentsLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is CommentsLoaded) {
          final comments = state.comments;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add comment section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add Comment',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                      SizedBox(height: isMobile ? 6 : 8),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        maxLines: isMobile ? 2 : 3,
                        style: TextStyle(fontSize: isMobile ? 12 : 14),
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) {
                            context.read<CommentBloc>().add(CreateComment(
                              documentId: _selectedDocument!.id,
                              content: text.trim(),
                            ));
                          }
                        },
                      ),
                      SizedBox(height: isMobile ? 6 : 8),
                      ElevatedButton(
                        onPressed: () {
                          // Handle comment submission
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 6 : 8,
                          ),
                          textStyle: TextStyle(fontSize: isMobile ? 12 : 14),
                        ),
                        child: const Text('Post Comment'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 12 : 16),
              // Comments list
              if (comments.isEmpty)
                Center(
                  child: Text(
                    'No comments yet. Be the first to comment!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: comments.map((comment) => _buildCommentItem(comment)).toList(),
                ),
            ],
          );
        } else if (state is CommentError) {
          return Center(
            child: Text('Error loading comments: ${state.error}'),
          );
        }
        return const Center(child: Text('No comments available.'));
      },
    );
  }

  Widget _buildDocumentVersionsContent() {
    if (_selectedDocument == null) return const SizedBox();

    return BlocBuilder<VersionBloc, VersionState>(
      builder: (context, state) {
        if (state is VersionsLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is VersionsLoaded) {
          final versions = state.versions;
          if (versions.isEmpty) {
            return const Center(
              child: Text('No version history available.'),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: versions.asMap().entries.map((entry) {
              final index = entry.key;
              final version = entry.value;
              return _buildVersionItem(version, index == 0);
            }).toList(),
          );
        } else if (state is VersionError) {
          return Center(
            child: Text('Error loading versions: ${state.error}'),
          );
        }
        return const Center(child: Text('No version history available.'));
      },
    );
  }

  Widget _buildDocumentActionsContent() {
    if (_selectedDocument == null) return const SizedBox();

    final isMobile = ResponsiveBuilder.isMobile(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.open_in_new, size: isMobile ? 20 : 24),
          title: Text(
            'Open Document',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: isMobile ? 14 : 16,
            ),
          ),
          subtitle: Text(
            'View the document in full screen',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: isMobile ? 11 : 13,
            ),
          ),
          dense: isMobile,
          onTap: () => _openDocument(_selectedDocument!),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.share, size: isMobile ? 20 : 24),
          title: Text(
            'Share Document',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: isMobile ? 14 : 16,
            ),
          ),
          subtitle: Text(
            'Generate a shareable link',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: isMobile ? 11 : 13,
            ),
          ),
          dense: isMobile,
          onTap: () => _shareDocument(_selectedDocument!),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.download, size: isMobile ? 20 : 24),
          title: Text(
            'Download Document',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: isMobile ? 14 : 16,
            ),
          ),
          subtitle: Text(
            'Download to your device',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: isMobile ? 11 : 13,
            ),
          ),
          dense: isMobile,
          onTap: () => _downloadDocument(_selectedDocument!),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.edit, size: isMobile ? 20 : 24),
          title: Text(
            'Edit Properties',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: isMobile ? 14 : 16,
            ),
          ),
          subtitle: Text(
            'Modify document properties',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: isMobile ? 11 : 13,
            ),
          ),
          dense: isMobile,
          onTap: () => _editDocumentProperties(_selectedDocument!),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            Icons.delete,
            color: theme.colorScheme.error,
            size: isMobile ? 20 : 24,
          ),
          title: Text(
            'Delete Document',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: isMobile ? 14 : 16,
              color: theme.colorScheme.error,
            ),
          ),
          subtitle: Text(
            'Permanently remove this document',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: isMobile ? 11 : 13,
            ),
          ),
          dense: isMobile,
          onTap: () => _showDeleteConfirmation(_selectedDocument!),
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
            onPressed: () => context.read<DocumentBloc>().add(LoadDocuments(folderId: _selectedFolderId)),
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
    
    // Load additional data for the selected document
    context.read<ActivityLogBloc>().add(LoadActivityLogs(documentId: document.id));
    context.read<CommentBloc>().add(LoadComments(document.id));
    context.read<VersionBloc>().add(LoadVersions(document.id));
  }

  void _openDocument(Document document) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(document: document),
      ),
    );
  }

  void _handleDocumentAction(Document document, String action) {
    switch (action) {
      case 'open':
        _openDocument(document);
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
              
              // Clear selected document if it's the one being deleted
              if (_selectedDocument?.id == document.id) {
                setState(() {
                  _selectedDocument = null;
                });
              }
              
              // Delete the document - the BlocListener will handle success/error messages
              // and the BlocBuilder will automatically refresh the list when the state changes
              context.read<DocumentBloc>().add(DeleteDocument(document.id, folderId: document.folderId));
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
          context.read<DocumentBloc>().add(LoadDocuments(folderId: _selectedFolderId));
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
        withData: true, // Ensure we get file data for web
        withReadStream: false, // Disable read stream for web compatibility
      );

      if (result != null) {
        final pickedFile = result.files.single;
        
        if (kIsWeb) {
          // For web platforms - use bytes
          if (pickedFile.bytes == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Could not read file data on web'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          
          // Use AddDocumentFromBytes for web
          context.read<DocumentBloc>().add(AddDocumentFromBytes(
            folderId: _selectedFolderId,
            fileBytes: pickedFile.bytes!,
            fileName: pickedFile.name,
            name: pickedFile.name,
          ));
          
        } else {
          // For mobile/desktop platforms - use file path
          if (pickedFile.path == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Could not get file path'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          
          final file = io.File(pickedFile.path!);
          
          // Use AddDocument for mobile/desktop
          context.read<DocumentBloc>().add(AddDocument(
            folderId: _selectedFolderId,
            file: file,
            name: pickedFile.name,
          ));
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploading ${pickedFile.name}...'),
            backgroundColor: Colors.blue,
          ),
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

  void _onSearchChanged(String query) {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 300), () {
      setState(() {}); // Just trigger rebuild, filtering happens in builder
    });
  }

  void _onSearchSubmitted(String query) {
    _searchDebouncer?.cancel();
    setState(() {}); // Just trigger rebuild, filtering happens in builder
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {}); // Just trigger rebuild, filtering happens in builder
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

  // Helper methods for new content sections
  Widget _buildAnalysisMetric(String label, String value) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 2 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: isMobile ? 12 : 14,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentStatsGrid() {
    final isMobile = ResponsiveBuilder.isMobile(context);
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Views',
                _getDocumentViewCount(),
                'view',
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: _buildStatCard(
                'Downloads',
                _getDocumentDownloadCount(),
                'download',
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Comments',
                _getDocumentCommentCount(),
                'create', // Using create color for comments as they create content
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: _buildStatCard(
                'Versions',
                _getDocumentVersionCount(),
                'edit', // Using edit color for versions as they relate to editing
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Shares',
                _getDocumentShareCount(),
                'share',
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: _buildStatCard(
                'Last Activity',
                _getLastActivityTime(),
                'recent', // Special case for recent activity
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String activityType) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Get activity colors, with special handling for 'recent' type
    final ActivityColors activityColors;
    if (activityType == 'recent') {
      // Use a neutral color for recent activity
      activityColors = ActivityColors(
        primary: colorScheme.outline,
        background: colorScheme.surfaceVariant,
        icon: Icons.schedule,
      );
    } else {
      activityColors = _getActivityColors(activityType);
    }
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: activityColors.background.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: activityColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                activityColors.icon, 
                color: activityColors.primary, 
                size: isMobile ? 16 : 20,
              ),
              Flexible(
                child: Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: isMobile ? 14 : 18,
                    fontWeight: FontWeight.bold,
                    color: activityColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: isMobile ? 10 : 12,
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySummary() {
    return BlocBuilder<ActivityLogBloc, ActivityLogState>(
      builder: (context, state) {
        if (state is ActivityLogsLoaded) {
          final recentActivities = state.activityLogs.take(3).toList();
          if (recentActivities.isEmpty) {
            return const Text('No recent activity');
          }
          
          return ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 400, // Prevent overflow by limiting height
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Activity items with reduced spacing
                ...recentActivities.map((activity) => _buildActivitySummaryItem(activity)),
                SizedBox(height: ResponsiveBuilder.isMobile(context) ? 8 : 12),
                // Activity chart with flexible sizing
                Flexible(
                  child: _buildActivityTypeChart(state.activityLogs),
                ),
              ],
            ),
          );
        } else if (state is ActivityLogsLoading) {
          return const Center(child: CircularProgressIndicator());
        } else {
          return const Text('No activity data available');
        }
      },
    );
  }

  Widget _buildActivitySummaryItem(ActivityLog activity) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final activityColors = _getActivityColors(activity.activityType);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 4 : 8),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: activityColors.background.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: activityColors.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isMobile ? 12 : 16,
            backgroundColor: activityColors.background,
            child: Icon(
              activityColors.icon, 
              color: activityColors.primary, 
              size: isMobile ? 12 : 16,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activity.activityTypeDisplay,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: isMobile ? 11 : 13,
                    color: activityColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${activity.username ?? 'User'} • ${_formatTimeAgo(activity.timestamp)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: isMobile ? 10 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTypeChart(List<ActivityLog> activities) {
    final Map<String, int> activityCounts = {};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = ResponsiveBuilder.isMobile(context);
    
    for (final activity in activities) {
      activityCounts[activity.activityType] = (activityCounts[activity.activityType] ?? 0) + 1;
    }

    if (activityCounts.isEmpty) {
      return const SizedBox();
    }

    // Limit to top 4 activities on mobile, all on desktop
    final sortedEntries = activityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayEntries = isMobile && sortedEntries.length > 4 
        ? sortedEntries.take(4).toList() 
        : sortedEntries;

    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Breakdown',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
          SizedBox(height: isMobile ? 4 : 8),
          // Use intrinsic height to prevent overflow
          IntrinsicHeight(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: displayEntries.map((entry) => 
                _buildActivityBar(entry.key, entry.value, activities.length)
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBar(String activityType, int count, int total) {
    final percentage = (count / total * 100).round();
    final theme = Theme.of(context);
    final isMobile = ResponsiveBuilder.isMobile(context);
    final activityColors = _getActivityColors(activityType);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 2 : 4),
      child: Row(
        children: [
          SizedBox(
            width: isMobile ? 40 : 60,
            child: Text(
              activityType.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: isMobile ? 8 : 10,
                fontWeight: FontWeight.w500,
                color: activityColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: isMobile ? 4 : 8),
          Expanded(
            child: Container(
              height: isMobile ? 3 : 4,
              decoration: BoxDecoration(
                color: activityColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                widthFactor: count / total,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: activityColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 4 : 8),
          SizedBox(
            width: isMobile ? 30 : 40,
            child: Text(
              isMobile ? '$count' : '$count ($percentage%)',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: isMobile ? 8 : 10,
                color: activityColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }



  String _getSecurityLevel(Document document) {
    // Simple security assessment based on document type and size
    if (document.type == DocumentType.pdf) {
      return 'Standard';
    } else if (document.type == DocumentType.csv) {
      return 'Data Sensitive';
    } else {
      return 'Standard';
    }
  }

  String _getContentSummary(Document document) {
    switch (document.type) {
      case DocumentType.pdf:
        return 'This PDF document contains structured content with potential images and formatted text. It may include forms, tables, or other interactive elements.';
      case DocumentType.csv:
        return 'This CSV file contains tabular data with rows and columns. It can be imported into spreadsheet applications or used for data analysis.';
      case DocumentType.docx:
        return 'This Word document contains formatted text with potential images, tables, and other rich content elements. It supports collaborative editing features.';
      case DocumentType.unsupported:
        return 'This document type is not fully supported for content analysis. Basic metadata and file operations are available.';
    }
  }

  Widget _buildActivityItem(ActivityLog activity) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final activityColors = _getActivityColors(activity.activityType);

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      color: activityColors.background.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: activityColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: activityColors.background,
          child: Icon(
            activityColors.icon, 
            color: activityColors.primary, 
            size: isMobile ? 16 : 18,
          ),
        ),
        title: Text(
          activity.description ?? 'Activity',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: activityColors.primary,
            fontWeight: FontWeight.w500,
            fontSize: isMobile ? 14 : 16,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${activity.username ?? 'User'} • ${_formatDate(activity.timestamp)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: isMobile ? 11 : 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatTime(activity.timestamp),
          style: theme.textTheme.bodySmall?.copyWith(
            color: activityColors.primary.withValues(alpha: 0.8),
            fontSize: isMobile ? 10 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        dense: isMobile,
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : 'U',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.userName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(comment.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editComment(comment);
                        break;
                      case 'delete':
                        _deleteComment(comment);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comment.content,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionItem(Version version, bool isLatest) {
    final isMobile = ResponsiveBuilder.isMobile(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: isMobile ? 16 : 20,
          backgroundColor: isLatest 
              ? colorScheme.primary.withValues(alpha: 0.1) 
              : colorScheme.outline.withValues(alpha: 0.1),
          child: Icon(
            isLatest ? Icons.check_circle : Icons.history,
            color: isLatest ? colorScheme.primary : colorScheme.outline,
            size: isMobile ? 16 : 20,
          ),
        ),
        title: Text(
          'Version ${version.versionNumber}${isLatest ? ' (Current)' : ''}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
            fontSize: isMobile ? 14 : 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              version.comment ?? 'No description',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isMobile ? 12 : 14,
              ),
              maxLines: isMobile ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              '${version.modifiedBy} • ${_formatDate(version.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: isMobile ? 10 : 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        dense: isMobile,
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: isMobile ? 18 : 24),
          onSelected: (value) {
            switch (value) {
              case 'view':
                _viewVersion(version);
                break;
              case 'restore':
                if (!isLatest) {
                  _restoreVersion(version);
                }
                break;
              case 'compare':
                _compareVersions(version);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View')),
            if (!isLatest)
              const PopupMenuItem(value: 'restore', child: Text('Restore')),
            const PopupMenuItem(value: 'compare', child: Text('Compare')),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Helper method to get theme-aware colors for different activity types
  ActivityColors _getActivityColors(String activityType) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    
    switch (activityType) {
      case 'create':
        return ActivityColors(
          primary: brightness == Brightness.light 
              ? const Color(0xFF2E7D32) // Dark green
              : const Color(0xFF4CAF50), // Light green
          background: brightness == Brightness.light
              ? const Color(0xFFE8F5E8) // Light green background
              : const Color(0xFF1B5E20), // Dark green background
          icon: Icons.add_circle,
        );
      case 'edit':
        return ActivityColors(
          primary: brightness == Brightness.light
              ? const Color(0xFF1565C0) // Dark blue
              : const Color(0xFF42A5F5), // Light blue
          background: brightness == Brightness.light
              ? const Color(0xFFE3F2FD) // Light blue background
              : const Color(0xFF0D47A1), // Dark blue background
          icon: Icons.edit,
        );
      case 'view':
        return ActivityColors(
          primary: brightness == Brightness.light
              ? const Color(0xFF616161) // Dark grey
              : const Color(0xFF9E9E9E), // Light grey
          background: brightness == Brightness.light
              ? const Color(0xFFF5F5F5) // Light grey background
              : const Color(0xFF424242), // Dark grey background
          icon: Icons.visibility,
        );
      case 'share':
        return ActivityColors(
          primary: brightness == Brightness.light
              ? const Color(0xFFE65100) // Dark orange
              : const Color(0xFFFF9800), // Light orange
          background: brightness == Brightness.light
              ? const Color(0xFFFFF3E0) // Light orange background
              : const Color(0xFFBF360C), // Dark orange background
          icon: Icons.share,
        );
      case 'download':
        return ActivityColors(
          primary: brightness == Brightness.light
              ? const Color(0xFF4527A0) // Dark purple
              : const Color(0xFF9C27B0), // Light purple
          background: brightness == Brightness.light
              ? const Color(0xFFF3E5F5) // Light purple background
              : const Color(0xFF311B92), // Dark purple background
          icon: Icons.download,
        );
      case 'delete':
        return ActivityColors(
          primary: brightness == Brightness.light
              ? const Color(0xFFC62828) // Dark red
              : const Color(0xFFEF5350), // Light red
          background: brightness == Brightness.light
              ? const Color(0xFFFFEBEE) // Light red background
              : const Color(0xFFB71C1C), // Dark red background
          icon: Icons.delete,
        );
      case 'restore':
        return ActivityColors(
          primary: brightness == Brightness.light
              ? const Color(0xFF00695C) // Dark teal
              : const Color(0xFF26A69A), // Light teal
          background: brightness == Brightness.light
              ? const Color(0xFFE0F2F1) // Light teal background
              : const Color(0xFF004D40), // Dark teal background
          icon: Icons.restore,
        );
      case 'rename':
        return ActivityColors(
          primary: brightness == Brightness.light
              ? const Color(0xFF5D4037) // Dark brown
              : const Color(0xFF8D6E63), // Light brown
          background: brightness == Brightness.light
              ? const Color(0xFFEFEBE9) // Light brown background
              : const Color(0xFF3E2723), // Dark brown background
          icon: Icons.drive_file_rename_outline,
        );
      case 'move':
        return ActivityColors(
          primary: brightness == Brightness.light
              ? const Color(0xFF283593) // Dark indigo
              : const Color(0xFF5C6BC0), // Light indigo
          background: brightness == Brightness.light
              ? const Color(0xFFE8EAF6) // Light indigo background
              : const Color(0xFF1A237E), // Dark indigo background
          icon: Icons.drive_file_move,
        );
      default:
        return ActivityColors(
          primary: colorScheme.outline,
          background: colorScheme.surfaceVariant,
          icon: Icons.info,
        );
    }
  }

  // Document statistics calculation methods
  String _getDocumentViewCount() {
    final activityState = context.read<ActivityLogBloc>().state;
    if (activityState is ActivityLogsLoaded) {
      final viewCount = activityState.activityLogs
          .where((activity) => activity.activityType == 'view')
          .length;
      return viewCount.toString();
    }
    // Fallback to simulated count
    final daysSinceCreation = DateTime.now().difference(_selectedDocument!.createdAt).inDays;
    return (daysSinceCreation * 2 + 5).toString();
  }

  String _getDocumentDownloadCount() {
    final activityState = context.read<ActivityLogBloc>().state;
    if (activityState is ActivityLogsLoaded) {
      final downloadCount = activityState.activityLogs
          .where((activity) => activity.activityType == 'download')
          .length;
      return downloadCount.toString();
    }
    // Fallback to simulated count
    final daysSinceCreation = DateTime.now().difference(_selectedDocument!.createdAt).inDays;
    return (daysSinceCreation ~/ 3 + 1).toString();
  }

  String _getDocumentCommentCount() {
    final commentState = context.read<CommentBloc>().state;
    if (commentState is CommentsLoaded) {
      return commentState.comments.length.toString();
    }
    return '0';
  }

  String _getDocumentVersionCount() {
    final versionState = context.read<VersionBloc>().state;
    if (versionState is VersionsLoaded) {
      return versionState.versions.length.toString();
    }
    return '1';
  }

  String _getDocumentShareCount() {
    final activityState = context.read<ActivityLogBloc>().state;
    if (activityState is ActivityLogsLoaded) {
      final shareCount = activityState.activityLogs
          .where((activity) => activity.activityType == 'share')
          .length;
      return shareCount.toString();
    }
    return '0';
  }

  String _getLastActivityTime() {
    final activityState = context.read<ActivityLogBloc>().state;
    if (activityState is ActivityLogsLoaded && activityState.activityLogs.isNotEmpty) {
      final lastActivity = activityState.activityLogs.first; // Assuming sorted by timestamp desc
      return _formatTimeAgo(lastActivity.timestamp);
    }
    // Fallback to document update time
    final lastUpdate = _selectedDocument!.updatedAt ?? _selectedDocument!.createdAt;
    return _formatTimeAgo(lastUpdate);
  }

  String _getOwnerDisplayName() {
    if (_selectedDocument!.ownerUsername != null && _selectedDocument!.ownerUsername!.isNotEmpty) {
      return _selectedDocument!.ownerUsername!;
    }
    // Fallback to owner ID if username is not available
    return _selectedDocument!.ownerId;
  }

  String _getFolderDisplayName(String folderId) {
    final folderState = context.read<FolderBloc>().state;
    if (folderState is FoldersLoaded) {
      final folder = folderState.folders.firstWhere(
        (f) => f.id == folderId,
        orElse: () => Folder.empty().copyWith(
          id: folderId,
          name: 'Unknown',
        ),
      );
      return '${folder.name} (${folderId})';
    }
    // Fallback to just folder ID if folders not loaded
    return folderId;
  }

  // Action handlers
  void _shareDocument(Document document) {
    showDialog(
      context: context,
      builder: (context) => _ShareDocumentDialog(document: document),
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
      final downloadUrl = '${API.baseUrl}/manager/document/${document.id}/download/';
      
      // Ensure filename has proper extension
      final fileName = _ensureFileExtension(document.name, document.type);
      
      if (kIsWeb) {
        // For web, programmatically trigger download
        try {
          final fileBytes = await _apiService.downloadFile(downloadUrl);
          
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
        final fileBytes = await _apiService.downloadFile(downloadUrl);
        
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

  void _editDocumentProperties(Document document) {
    showDialog(
      context: context,
      builder: (context) => _EditDocumentPropertiesDialog(
        document: document,
        onDocumentUpdated: () {
          // Refresh the document list
          context.read<DocumentBloc>().add(LoadDocuments(folderId: _selectedFolderId));
          // Clear selection to refresh details panel
          setState(() {
            _selectedDocument = null;
          });
        },
      ),
    );
  }

  void _editComment(Comment comment) {
    // TODO: Implement edit comment functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit comment functionality coming soon!')),
    );
  }

  void _deleteComment(Comment comment) {
    // TODO: Implement delete comment functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CommentBloc>().add(DeleteComment(comment.id));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _viewVersion(Version version) {
    // TODO: Implement view version functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing version ${version.versionNumber}')),
    );
  }

  void _restoreVersion(Version version) {
    // TODO: Implement restore version functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Version'),
        content: Text('Are you sure you want to restore to version ${version.versionNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DocumentBloc>().add(RestoreVersion(
                documentId: _selectedDocument!.id,
                versionId: version.versionId,
              ));
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _compareVersions(Version version) {
    // TODO: Implement compare versions functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Comparing with version ${version.versionNumber}')),
    );
  }
}

class _ShareDocumentDialog extends StatefulWidget {
  final Document document;

  const _ShareDocumentDialog({
    required this.document,
  });

  @override
  State<_ShareDocumentDialog> createState() => _ShareDocumentDialogState();
}

class _ShareDocumentDialogState extends State<_ShareDocumentDialog> {
  final ShareableLinkRepository _shareableLinkRepository = ShareableLinkRepository();
  ShareableLink? _shareableLink;
  bool _isLoading = false;
  bool _isCreating = false;
  DateTime? _expiryDate;
  final TextEditingController _expiryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingLink();
  }

  @override
  void dispose() {
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingLink() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final links = await _shareableLinkRepository.getShareableLinks();
      final existingLink = links.firstWhere(
        (link) => link.documentId == widget.document.id && link.isActive,
        orElse: () => ShareableLink(
          id: '',
          documentId: '',
          token: '',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now(),
          isActive: false,
          createdBy: '',
          permissionType: '',
        ),
      );

      if (existingLink.id.isNotEmpty) {
        setState(() {
          _shareableLink = existingLink;
        });
      }
    } catch (e) {
      // No existing link or error loading, that's okay
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createShareableLink() async {
    setState(() {
      _isCreating = true;
    });

    try {
      DateTime expiryDate = _expiryDate ?? DateTime.now().add(const Duration(days: 7));
      
      final newLink = await _shareableLinkRepository.createShareableLink(
        widget.document.id,
        expiryDate,
      );

      setState(() {
        _shareableLink = newLink;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shareable link created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating shareable link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  Future<void> _copyLinkToClipboard() async {
    if (_shareableLink != null) {
      final shareUrl = 'https://docm.app/share/${_shareableLink!.token}';
      await Clipboard.setData(ClipboardData(text: shareUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _selectExpiryDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        _expiryDate = pickedDate;
        _expiryController.text = _formatDate(pickedDate);
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveBuilder.isMobile(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.share, color: theme.primaryColor),
          const SizedBox(width: 8),
          const Text('Share Document'),
        ],
      ),
      content: SizedBox(
        width: isMobile ? null : 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document: ${widget.document.name}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_isLoading) ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
            ] else if (_shareableLink != null) ...[
              const Text(
                'Share Link:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            'https://docm.app/share/${_shareableLink!.token}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: _copyLinkToClipboard,
                          tooltip: 'Copy link',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expires: ${_formatDate(_shareableLink!.expiresAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const Text('No shareable link created yet.'),
              const SizedBox(height: 16),
              
              // Expiry date selection
              TextField(
                controller: _expiryController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Expiry Date',
                  hintText: 'Select expiry date',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _selectExpiryDate,
                  ),
                ),
                onTap: _selectExpiryDate,
              ),
              const SizedBox(height: 8),
              Text(
                'Default: 7 days from now',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (_shareableLink == null) ...[
          ElevatedButton.icon(
            onPressed: _isCreating ? null : _createShareableLink,
            icon: _isCreating 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            label: const Text('Create Link'),
          ),
        ],
      ],
    );
  }
}

class _EditDocumentPropertiesDialog extends StatefulWidget {
  final Document document;
  final VoidCallback onDocumentUpdated;

  const _EditDocumentPropertiesDialog({
    required this.document,
    required this.onDocumentUpdated,
  });

  @override
  State<_EditDocumentPropertiesDialog> createState() => _EditDocumentPropertiesDialogState();
}

class _EditDocumentPropertiesDialogState extends State<_EditDocumentPropertiesDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedFolderId;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.document.name;
    _selectedFolderId = widget.document.folderId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateDocument() async {
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
      _isUpdating = true;
    });

    try {
      context.read<DocumentBloc>().add(UpdateDocument(
        id: widget.document.id,
        name: _nameController.text.trim(),
        folderId: _selectedFolderId,
      ));

      Navigator.pop(context);
      widget.onDocumentUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveBuilder.isMobile(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: theme.primaryColor),
          const SizedBox(width: 8),
          const Text('Edit Document Properties'),
        ],
      ),
      content: SizedBox(
        width: isMobile ? null : 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Document Name',
                hintText: 'Enter document name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            
            // Folder selection
            BlocBuilder<FolderBloc, FolderState>(
              builder: (context, folderState) {
                if (folderState is FolderLoaded) {
                  return DropdownButtonFormField<String?>(
                    value: _selectedFolderId,
                    decoration: const InputDecoration(
                      labelText: 'Folder',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Root Folder'),
                      ),
                      ...folderState.folders.map((folder) => DropdownMenuItem<String?>(
                        value: folder.id,
                        child: Text(folder.name),
                      )),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        _selectedFolderId = value;
                      });
                    },
                  );
                } else {
                  return const TextField(
                    decoration: InputDecoration(
                      labelText: 'Folder',
                      hintText: 'Loading folders...',
                      border: OutlineInputBorder(),
                      enabled: false,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Document info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document Information',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.insert_drive_file, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Type: ${widget.document.type.toString().split('.').last.toUpperCase()}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Created: ${_formatDate(widget.document.createdAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (widget.document.updatedAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.update, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Updated: ${_formatDate(widget.document.updatedAt!)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateDocument,
          child: _isUpdating
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

      // Create document
      context.read<DocumentBloc>().add(CreateDocument(
        name: fileName,
        folderId: widget.folderId,
        content: initialContent,
      ));

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
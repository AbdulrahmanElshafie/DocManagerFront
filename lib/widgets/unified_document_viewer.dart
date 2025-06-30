import 'dart:io';
import 'package:flutter/material.dart';
import 'package:universal_file_viewer/universal_file_viewer.dart';
import 'package:open_file/open_file.dart';
import '../models/document.dart';
import '../widgets/versions_section.dart';
import '../widgets/comments_section.dart';
import '../widgets/improved_pdf_viewer.dart';

class UnifiedDocumentViewer extends StatefulWidget {
  final Document document;
  final VoidCallback? onDocumentUpdated;

  const UnifiedDocumentViewer({
    super.key,
    required this.document,
    this.onDocumentUpdated,
  });

  @override
  State<UnifiedDocumentViewer> createState() => _UnifiedDocumentViewerState();
}

class _UnifiedDocumentViewerState extends State<UnifiedDocumentViewer>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _currentTabTitle = 'Viewer';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Set the tab title based on document type
    _currentTabTitle = _getTabTitle(widget.document.type);
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getTabTitle(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
      case DocumentType.docx:
      case DocumentType.csv:
        return 'Viewer'; // All types are now viewable in-app
      case DocumentType.unsupported:
        return 'Preview';
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      switch (index) {
        case 0:
          _currentTabTitle = _getTabTitle(widget.document.type);
          break;
        case 1:
          _currentTabTitle = 'Versions';
          break;
        case 2:
          _currentTabTitle = 'Comments';
          break;
      }
    });
  }

  Widget _buildDocumentViewer() {
    // Check if document type is supported by UniversalFileViewer
    if (widget.document.type == DocumentType.unsupported) {
      return _buildUnsupportedView();
    }

    // Use UniversalFileViewer for all supported document types
    return _buildUniversalViewer();
  }

  Widget _buildUniversalViewer() {
    final fileUrl = widget.document.getAbsoluteFileUrl();

    // If we have a valid file URL, create a temporary file reference
    if (fileUrl != null) {
      try {
        // For web and remote files, try creating a File object from the URL
        // Note: This might not work for all platforms, especially web
        final file = File(fileUrl);
        return UniversalFileViewer(
          file: file,
        );
      } catch (e) {
        // If File creation doesn't work, fallback to error view
        print('UniversalFileViewer error: $e');
        return _buildErrorView();
      }
    }

    // Fallback to error view if no URL available
    return _buildErrorView();
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
          const SizedBox(height: 24),
          Text(
            'Error Loading Document',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Unable to display this document',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open External'),
          ),
        ],
      ),
    );
  }

  void _openExternally() async {
    final fileUrl = widget.document.getAbsoluteFileUrl();
    if (fileUrl != null) {
      try {
        final result = await OpenFile.open(fileUrl);
        if (result.type != ResultType.done) {
          _showErrorSnackBar('Could not open file: ${result.message}');
        }
      } catch (e) {
        _showErrorSnackBar('Error opening file: $e');
      }
    } else {
      _showErrorSnackBar('No file URL available');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildUnsupportedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.orange[300],
          ),
          const SizedBox(height: 24),
          Text(
            'Unsupported File Type',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.orange[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cannot preview this file type in the app',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.document.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Supported formats:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('• PDF documents (editable)'),
          const Text('• Word documents (.docx)'),
          const Text('• CSV spreadsheets'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.document.name,
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              _getDocumentTypeString(widget.document.type),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[300],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(_getTabIcon(widget.document.type)),
              text: _getTabTitle(widget.document.type),
            ),
            const Tab(
              icon: Icon(Icons.history),
              text: 'Versions',
            ),
            const Tab(
              icon: Icon(Icons.comment),
              text: 'Comments',
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showDocumentInfo(),
            icon: const Icon(Icons.info_outline),
            tooltip: 'Document Info',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Document Viewer Tab
          _buildDocumentViewer(),
          
          // Versions Tab
          VersionsSection(documentId: widget.document.id),
          
          // Comments Tab
          CommentsSection(documentId: widget.document.id),
        ],
      ),
    );
  }

  IconData _getTabIcon(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
      case DocumentType.docx:
      case DocumentType.csv:
        return Icons.visibility; // All types are viewable in-app
      case DocumentType.unsupported:
        return Icons.preview;
    }
  }

  String _getDocumentTypeString(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return 'PDF Document';
      case DocumentType.docx:
        return 'Word Document';
      case DocumentType.csv:
        return 'CSV Spreadsheet';
      case DocumentType.unsupported:
        return 'Unsupported Format';
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _refreshCurrentTab();
        break;
      case 'share':
        _shareDocument();
        break;
    }
  }

  void _refreshCurrentTab() {
    // Force refresh of current tab content
    setState(() {
      // This will rebuild the current tab
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Content refreshed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareDocument() {
    // TODO: Implement document sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDocumentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', widget.document.name),
            _buildInfoRow('Type', _getDocumentTypeString(widget.document.type)),
            _buildInfoRow('Created', _formatDate(widget.document.createdAt)),
            if (widget.document.updatedAt != null)
              _buildInfoRow('Modified', _formatDate(widget.document.updatedAt!)),
            _buildInfoRow('ID', widget.document.id),
            if (widget.document.folderId != null)
              _buildInfoRow('Folder', widget.document.folderId!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document.dart';
import 'csv_screen.dart';
import 'docx_screen.dart';

class DocumentViewerScreen extends StatefulWidget {
  final Document document;
  
  const DocumentViewerScreen({
    super.key,
    required this.document,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late PdfViewerController _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.document.getAbsoluteFileUrl();
    if (url == null) return _errorState("No URL for this document");

    switch (widget.document.type) {
      case DocumentType.pdf:
        return _buildPdf(url);
      case DocumentType.csv:
        return CsvScreen(url: url);
      case DocumentType.docx:
        return DocxScreen(
          url: url,
          name: widget.document.name.endsWith('.docx')
              ? widget.document.name
              : '${widget.document.name}.docx',
        );
      default:
        return _errorState("Unsupported format");
    }
  }

  Widget _buildPdf(String url) => Scaffold(
    appBar: AppBar(
      title: Text(widget.document.name),
      actions: [
        IconButton(
          onPressed: _showSearchDialog,
          icon: const Icon(Icons.search),
          tooltip: 'Search',
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('Document Info'),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        // PDF Toolbar
        Container(
          padding: const EdgeInsets.all(8.0),
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
              IconButton(
                onPressed: () => _pdfController.zoomLevel = _pdfController.zoomLevel * 0.8,
                icon: const Icon(Icons.zoom_out),
                tooltip: 'Zoom Out',
              ),
              IconButton(
                onPressed: () => _pdfController.zoomLevel = _pdfController.zoomLevel * 1.2,
                icon: const Icon(Icons.zoom_in),
                tooltip: 'Zoom In',
              ),
            ],
          ),
        ),
        
        // PDF Viewer
        Expanded(
          child: SfPdfViewer.network(
            url,
            controller: _pdfController,
            canShowScrollStatus: true,
            canShowScrollHead: true,
            canShowPaginationDialog: true,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
          ),
        ),
      ],
    ),
  );





  Widget _errorState(String msg) => Scaffold(
    appBar: AppBar(title: Text(widget.document.name)),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
  );

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not launch $url');
    }
  }

  void _showSearchDialog() {
    String searchText = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search PDF'),
        content: TextField(
          onChanged: (value) => searchText = value,
          decoration: const InputDecoration(
            hintText: 'Enter search text...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (searchText.trim().isNotEmpty) {
                _pdfController.searchText(searchText);
                Navigator.pop(context);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'info':
        _showDocumentInfo();
        break;
      case 'external':
        _launchUrl(widget.document.getAbsoluteFileUrl() ?? '');
        break;
    }
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
            _buildInfoRow('Type', _getDocumentTypeString()),
            _buildInfoRow('Created', _formatDate(widget.document.createdAt)),
            if (widget.document.updatedAt != null)
              _buildInfoRow('Modified', _formatDate(widget.document.updatedAt!)),
            _buildInfoRow('ID', widget.document.id),
            if (widget.document.folderId.isNotEmpty)
              _buildInfoRow('Folder', widget.document.folderId),
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getDocumentTypeString() {
    switch (widget.document.type) {
      case DocumentType.pdf:
        return 'PDF Document';
      case DocumentType.csv:
        return 'CSV Spreadsheet';
      case DocumentType.docx:
        return 'Word Document';
      case DocumentType.unsupported:
        return 'Unsupported Format';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
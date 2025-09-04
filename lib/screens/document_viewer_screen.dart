import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document.dart';
import 'csv_screen.dart';
import 'docx_screen.dart';
import '../shared/network/api_service.dart';
import '../shared/utils/web_download_helper.dart'
    if (dart.library.html) '../shared/utils/web_download_helper.dart';

// Conditional import for HTML (web platform only)
import 'dart:html' as html show Blob, Url;

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
  final ApiService _apiService = ApiService();
  
  // Conversion state
  bool _isConverting = false;
  String? _convertedPdfUrl;
  Uint8List? _convertedPdfBytes;
  String? _conversionError;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    
    // Auto-convert DOCX files
    if (widget.document.type == DocumentType.docx) {
      _convertDocxToPdf();
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _convertDocxToPdf() async {
    if (widget.document.type != DocumentType.docx) return;
    
    setState(() {
      _isConverting = true;
      _conversionError = null;
    });

    try {
      final pdfBytes = await _apiService.convertDocxToPdf(widget.document.id);
      
      if (kIsWeb) {
        // For web, create a blob URL with proper MIME type
        final blob = html.Blob([pdfBytes], 'application/pdf');
        _convertedPdfUrl = html.Url.createObjectUrlFromBlob(blob);
      } else {
        // For mobile, store bytes
        _convertedPdfBytes = Uint8List.fromList(pdfBytes);
      }
      
      setState(() {
        _isConverting = false;
      });
      
    } catch (e) {
      setState(() {
        _isConverting = false;
        _conversionError = e.toString();
      });
      
      // Fallback to original DOCX handling
      _showErrorSnackBar('Failed to convert DOCX to PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.document.type) {
      case DocumentType.pdf:
        return _buildPdf(widget.document.getAbsoluteFileUrl()!);
      
      case DocumentType.csv:
        return CsvScreen(url: widget.document.getAbsoluteFileUrl()!);
      
      case DocumentType.docx:
        // Handle DOCX conversion
        if (_isConverting) {
          return _buildConversionLoadingScreen();
        } else if (_conversionError != null) {
          return _buildConversionErrorScreen();
        } else if (_convertedPdfUrl != null || _convertedPdfBytes != null) {
          return _buildConvertedPdfViewer();
        } else {
          // Fallback to original DOCX screen
          return DocxScreen(
            url: widget.document.getAbsoluteFileUrl()!,
            name: widget.document.name,
          );
        }
      
      default:
        return _errorState("Unsupported format");
    }
  }

  Widget _buildConversionLoadingScreen() {
    return Scaffold(
      appBar: AppBar(title: Text(widget.document.name)),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Converting DOCX to PDF...'),
            SizedBox(height: 8),
            Text('This may take a few moments', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildConversionErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _convertDocxToPdf,
            tooltip: 'Retry conversion',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to convert DOCX to PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _conversionError ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _convertDocxToPdf,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Fallback to original DOCX viewer
                    setState(() {
                      _conversionError = null;
                      _convertedPdfUrl = null;
                      _convertedPdfBytes = null;
                    });
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Original'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConvertedPdfViewer() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.name.replaceFirst('.docx', '.pdf')),
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
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Download PDF'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Conversion notice
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'DOCX file converted to PDF for viewing',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    // Could hide this notice
                  },
                ),
              ],
            ),
          ),
          
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
            child: kIsWeb && _convertedPdfUrl != null
              ? SfPdfViewer.network(
                  _convertedPdfUrl!,
                  controller: _pdfController,
                  canShowScrollStatus: true,
                  canShowScrollHead: true,
                  canShowPaginationDialog: true,
                  enableDoubleTapZooming: true,
                  enableTextSelection: true,
                )
              : _convertedPdfBytes != null
                ? SfPdfViewer.memory(
                    _convertedPdfBytes!,
                    controller: _pdfController,
                    canShowScrollStatus: true,
                    canShowScrollHead: true,
                    canShowPaginationDialog: true,
                    enableDoubleTapZooming: true,
                    enableTextSelection: true,
                  )
                : const Center(child: Text('PDF not available')),
          ),
        ],
      ),
    );
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
      case 'download':
        _downloadConvertedPdf();
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

  Future<void> _downloadConvertedPdf() async {
    if (_convertedPdfBytes != null) {
      final fileName = widget.document.name.replaceFirst('.docx', '.pdf');
      WebDownloadHelper.downloadFile(_convertedPdfBytes!, fileName);
    }
  }
}
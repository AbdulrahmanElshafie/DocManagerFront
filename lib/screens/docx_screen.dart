import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../models/document.dart';
import '../shared/network/api_service.dart';

class DocxScreen extends StatefulWidget {
  final Document document;
  const DocxScreen({Key? key, required this.document})
      : super(key: key);

  @override
  _DocxScreenState createState() => _DocxScreenState();
}

class _DocxScreenState extends State<DocxScreen> {
  late PdfViewerController _pdfController;
  String? _pdfBlobUrl;
  bool _loading = true, _error = false;
  String _errorMessage = '';
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _convertDocxToPdf();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _convertDocxToPdf() async {
    try {
      setState(() {
        _loading = true;
        _error = false;
        _errorMessage = '';
        _pdfBlobUrl = null;
      });

      // Call the conversion API
      final pdfBytes = await _apiService.convertDocxToPdf(widget.document.id);
      
      // Create blob URL for the PDF
      if (kIsWeb) {
        final blob = Uint8List.fromList(pdfBytes);
        // For web, we'll create a data URL
        final base64String = base64Encode(blob);
        _pdfBlobUrl = 'data:application/pdf;base64,$base64String';
      } else {
        // For mobile/desktop, create a temporary file
        final tempFile = File('${(await getTemporaryDirectory()).path}/converted_${widget.document.id}.pdf');
        await tempFile.writeAsBytes(pdfBytes);
        _pdfBlobUrl = tempFile.path;
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _openExternally() async {
    try {
      final url = widget.document.getAbsoluteFileUrl();
      if (url == null) {
        _showErrorSnackBar('No URL available for this document');
        return;
      }
      
      final uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) {
        _showErrorSnackBar(kIsWeb 
          ? 'Could not open document in browser' 
          : 'Could not launch external viewer');
        return;
      }
      await launchUrl(uri, mode: kIsWeb 
          ? LaunchMode.platformDefault 
          : LaunchMode.externalApplication);
    } catch (e) {
      _showErrorSnackBar(kIsWeb 
          ? 'Failed to open document in browser: ${e.toString()}' 
          : 'Failed to launch external viewer: ${e.toString()}');
    }
  }

  Future<void> _retry() async {
    await _convertDocxToPdf();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.document.name)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Converting document to PDF...'),
            ],
          ),
        ),
      );
    }
    
    // Error state
    if (_error || _pdfBlobUrl == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.document.name)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to convert ${widget.document.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _errorMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _openExternally,
                    child: const Text('Open Original'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    
    // Success state - show PDF viewer
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reconvert document',
            onPressed: _retry,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open original document',
            onPressed: _openExternally,
          ),
        ],
      ),
      body: Column(
        children: [
          // PDF Toolbar (similar to document_viewer_screen.dart)
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
                const Spacer(),
                const Text('Converted from DOCX', 
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          
          // PDF Viewer
          Expanded(
            child: kIsWeb 
              ? SfPdfViewer.memory(
                  base64Decode(_pdfBlobUrl!.split(',')[1]), // Remove data:application/pdf;base64, prefix
                  controller: _pdfController,
                  canShowScrollStatus: true,
                  canShowScrollHead: true,
                  canShowPaginationDialog: true,
                  enableDoubleTapZooming: true,
                  enableTextSelection: true,
                )
              : SfPdfViewer.file(
                  File(_pdfBlobUrl!),
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
  }
} 
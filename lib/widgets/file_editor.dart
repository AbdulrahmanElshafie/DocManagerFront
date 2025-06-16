import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/document.dart';
import '../shared/utils/logger.dart';
import '../shared/network/api_service.dart';
import 'super_editor_widget.dart';
import 'improved_pdf_viewer.dart';
import 'improved_csv_editor.dart';
import 'version_management_widget.dart';

class FileEditor extends StatefulWidget {
  final Document? document;
  final File? file;
  final Function(String content, DocumentType type)? onSave;
  final Function(File file)? onSaveFile;

  const FileEditor({
    super.key,
    this.document,
    this.file,
    this.onSave,
    this.onSaveFile,
  });

  @override
  State<FileEditor> createState() => _FileEditorState();
}

class _FileEditorState extends State<FileEditor> with TickerProviderStateMixin {
  DocumentType? _fileType;
  String? _fileName;
  File? _currentFile;
  String? _fileUrl; // For remote files
  bool _isRemoteFile = false;
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _fileBytes; // For web or downloaded remote files
  
  late TabController _tabController;

  // Content data
  String? _documentContent;
  String? _csvContent;
  List<List<String>>? _csvData;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeEditor();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isUrl(String? path) {
    if (path == null) return false;
    return path.startsWith('http://') || path.startsWith('https://');
  }

  bool _isRelativeApiPath(String? path) {
    if (path == null) return false;
    return path.startsWith('/media/') || path.startsWith('media/');
  }

  String _makeFullUrl(String relativePath) {
    // Convert relative API path to full URL
    final baseUrl = 'http://localhost:8000';
    if (relativePath.startsWith('/')) {
      return '$baseUrl$relativePath';
    } else {
      return '$baseUrl/$relativePath';
    }
  }

  Future<void> _initializeEditor() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (widget.document != null) {
        _fileName = widget.document!.name;
        _fileType = widget.document!.type;
        
        // Check if the file path is a URL or local path
        final filePath = widget.document!.filePath ?? widget.document!.file?.path;
        
        if (_isUrl(filePath)) {
          _isRemoteFile = true;
          _fileUrl = filePath;
          LoggerUtil.info('Remote file detected: $_fileUrl');
        } else if (_isRelativeApiPath(filePath)) {
          _isRemoteFile = true;
          _fileUrl = _makeFullUrl(filePath!);
          LoggerUtil.info('Relative API path converted to URL: $_fileUrl');
        } else {
          _isRemoteFile = false;
          _currentFile = widget.document!.file;
        }
      } else if (widget.file != null) {
        _isRemoteFile = false;
        _currentFile = widget.file;
        _fileName = path.basename(widget.file!.path);
        _fileType = _inferFileType(_fileName!);
      } else {
        throw Exception('No document or file provided');
      }

      await _loadFileContent();

    } catch (e) {
      LoggerUtil.error('Error initializing file editor: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Uint8List> _downloadRemoteFile(String url) async {
    try {
      LoggerUtil.info('Downloading remote file: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        LoggerUtil.info('File downloaded successfully, size: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download file: HTTP ${response.statusCode}');
      }
    } catch (e) {
      LoggerUtil.error('Error downloading remote file: $e');
      rethrow;
    }
  }

  DocumentType _inferFileType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.csv':
        return DocumentType.csv;
      case '.pdf':
        return DocumentType.pdf;
      case '.docx':
      case '.doc':
        return DocumentType.docx;
      default:
        return DocumentType.unsupported;
    }
  }

  Future<void> _loadFileContent() async {
    try {
      // For remote files, download them first
      if (_isRemoteFile && _fileUrl != null) {
        _fileBytes = await _downloadRemoteFile(_fileUrl!);
      }

      switch (_fileType!) {
        case DocumentType.csv:
          await _loadCSVContent();
          break;
        case DocumentType.pdf:
          await _loadPDFContent();
          break;
        case DocumentType.docx:
          await _loadDOCXContent();
          break;
        case DocumentType.unsupported:
          throw Exception('Unsupported file type');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      LoggerUtil.error('Error loading file content: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCSVContent() async {
    try {
      String csvText;
      
      if (widget.document != null) {
        // Get CSV content from API
        try {
          final response = await _apiService.get(
            '/manager/document/${widget.document!.id}/content/',
            {},
          );
          
          csvText = response['content'] ?? '';
          if (csvText.isEmpty) {
            // Create empty CSV content if none exists
            csvText = 'Column A,Column B,Column C\nValue 1,Value 2,Value 3\n';
          }
        } catch (e) {
          LoggerUtil.warning('Could not load CSV from API, creating empty CSV: $e');
          csvText = 'Column A,Column B,Column C\nValue 1,Value 2,Value 3\n';
        }
      } else if (_isRemoteFile && _fileBytes != null) {
        csvText = utf8.decode(_fileBytes!);
      } else if (_currentFile != null) {
        csvText = await _currentFile!.readAsString();
      } else {
        throw Exception('No file data available');
      }

      setState(() {
        _csvContent = csvText;
      });

      LoggerUtil.info('CSV content loaded successfully');
    } catch (e) {
      LoggerUtil.error('Error loading CSV content: $e');
      rethrow;
    }
  }

  Future<void> _loadPDFContent() async {
    try {
      if (_isRemoteFile) {
        // For remote files, download the bytes if not already downloaded
        if (_fileBytes == null && _fileUrl != null) {
          _fileBytes = await _downloadRemoteFile(_fileUrl!);
        }
        LoggerUtil.info('PDF loaded from remote URL, size: ${_fileBytes?.length ?? 0} bytes');
      } else if (_currentFile != null) {
        // For local files, read as bytes
        _fileBytes = await _currentFile!.readAsBytes();
        LoggerUtil.info('PDF loaded from local file, size: ${_fileBytes!.length} bytes');
      } else {
        throw Exception('No PDF data available');
      }
      
      if (_fileBytes == null || _fileBytes!.isEmpty) {
        throw Exception('PDF file is empty or could not be loaded');
      }
    } catch (e) {
      LoggerUtil.error('Error loading PDF content: $e');
      rethrow;
    }
  }

  Future<void> _loadDOCXContent() async {
    try {
      if (widget.document != null) {
        // Get document content from API as HTML for Super Editor
        try {
          final response = await _apiService.get(
            '/manager/document/${widget.document!.id}/content/',
            {'format': 'html'},
          );
          
          setState(() {
            _documentContent = response['content'] ?? '<p>Start typing your document...</p>';
          });
          
          LoggerUtil.info('DOCX content loaded as HTML from API');
        } catch (e) {
          LoggerUtil.warning('Could not load DOCX from API, creating empty content: $e');
          setState(() {
            _documentContent = '<p>Start typing your document...</p>';
          });
        }
      } else {
        throw Exception('Document API access not available for local files');
      }
    } catch (e) {
      LoggerUtil.error('Error loading DOCX content: $e');
      setState(() {
        _documentContent = '<p>Error loading document. Start typing your document...</p>';
      });
    }
  }

  Future<void> _saveDocumentContent(String content, String contentType) async {
    if (widget.document == null) {
      LoggerUtil.error('Cannot save without document reference');
      return;
    }

    try {
      await _apiService.updateDocumentContent(
        widget.document!.id,
        content,
        contentType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      LoggerUtil.error('Error saving document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveCsvData(List<List<String>> data) async {
    try {
      const converter = ListToCsvConverter();
      final csvContent = converter.convert(data);

      if (widget.document != null) {
        // Save via API
        await _apiService.updateDocumentContent(
          widget.document!.id,
          csvContent,
          'csv',
        );
      } else if (_currentFile != null) {
        // Save to local file
        await _currentFile!.writeAsString(csvContent);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV data saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      LoggerUtil.error('Error saving CSV data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEditor() {
    switch (_fileType!) {
      case DocumentType.csv:
        return ImprovedCsvEditor(
          document: widget.document!,
          csvContent: _csvContent,
          onSave: _saveCsvData,
        );
      
      case DocumentType.pdf:
        return ImprovedPdfViewer(
          document: widget.document!,
          pdfBytes: _fileBytes,
          pdfUrl: _isRemoteFile ? _fileUrl : null,
        );
      
      case DocumentType.docx:
        return SuperEditorWidget(
          document: widget.document!,
          initialContent: _documentContent,
          contentFormat: 'html',
          onSave: _saveDocumentContent,
        );
      
      case DocumentType.unsupported:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Unsupported file type'),
            ],
          ),
        );
    }
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Editor Tab
        _buildEditor(),
        
        // Version Management Tab
        widget.document != null 
          ? VersionManagementWidget(document: widget.document!)
          : const Center(child: Text('Version management not available for local files')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading file...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_fileName ?? 'File Editor'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_errorMessage'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeEditor,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName ?? 'File Editor'),
        bottom: widget.document != null 
          ? TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.edit), text: 'Editor'),
                Tab(icon: Icon(Icons.history), text: 'Versions'),
              ],
            )
          : null,
        actions: [
          if (_fileType == DocumentType.pdf || _fileType == DocumentType.csv)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    _initializeEditor();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Refresh'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: widget.document != null ? _buildTabContent() : _buildEditor(),
    );
  }
} 
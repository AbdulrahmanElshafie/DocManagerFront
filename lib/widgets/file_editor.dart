import 'dart:io' as io show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import '../shared/utils/file_utils.dart';
import '../models/document.dart';
import '../shared/utils/logger.dart';
import '../shared/network/api.dart';
import 'improved_pdf_viewer.dart';  
import 'version_management_widget.dart';
// Conditional import for web-specific functionality
import 'dart:html' if (dart.library.html) 'dart:html' as html;

class FileEditor extends StatefulWidget {
  final Document? document;
  final io.File? file;
  final Function(String content, DocumentType type)? onSave;
  final Function(io.File file)? onSaveFile;

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
  String? _fileUrl; // For remote files
  String? _filePath; // For local files or downloaded files
  bool _isRemoteFile = false;
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _fileBytes; // For web or downloaded remote files
  
  late TabController _tabController;

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
    // Use the base URL from API configuration, removing the '/api' suffix
    final baseUrl = API.baseUrl.replaceAll('/api', '');
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
        final filePath = widget.document!.filePath ?? FileUtils.getFilePath(widget.document!.file);
        
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
          _filePath = filePath;
        }
      } else if (widget.file != null) {
        _isRemoteFile = false;
        try {
          if (kIsWeb) {
            _fileName = 'web_file';
          } else {
            _fileName = FileUtils.getFileName(widget.file!);
            _filePath = FileUtils.getFilePath(widget.file!);
          }
        } catch (e) {
          _fileName = 'unknown_file';
        }
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
        
        // For DOCX and CSV files, handle platform-specific file access
        if (_fileType == DocumentType.docx || _fileType == DocumentType.csv) {
          if (kIsWeb) {
            // On web, we can't save to file system, so we'll just keep the bytes in memory
            // and show a simple preview with download option
            LoggerUtil.info('Web platform: keeping file in memory');
          } else {
            // On mobile/desktop, save to temp directory for external app opening
            try {
              final tempDir = await getTemporaryDirectory();
              final tempFile = io.File('${tempDir.path}/$_fileName');
              await tempFile.writeAsBytes(_fileBytes!);
              _filePath = tempFile.path;
              LoggerUtil.info('Saved remote file to temp path: $_filePath');
            } catch (e) {
              LoggerUtil.error('Error saving to temp directory: $e');
              // Fall back to in-memory handling
            }
          }
        }
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

  Widget _buildEditor() {
    switch (_fileType!) {
      case DocumentType.csv:
      case DocumentType.docx:
        // Use universal_file_viewer for DOCX and CSV files
        // Check if we have either a local file path or downloaded file bytes
        if (_filePath != null || _fileBytes != null) {
          return Column(
            children: [
              // View-only notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Document viewer for ${_fileType == DocumentType.docx ? 'DOCX' : 'CSV'} files.',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ),
                    // Only show "Open External" button if we have a local file path
                    if (_filePath != null)
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final result = await OpenFile.open(_filePath!);
                            if (result.type != ResultType.done) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not open file: ${result.message}'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error opening file: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open External'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 28),
                        ),
                      ),
                  ],
                ),
              ),
              // Universal file viewer
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: _buildFileViewerWithFallback(),
                ),
              ),
            ],
          );
        } else {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('File not available for viewing'),
              ],
            ),
          );
        }
      
      case DocumentType.pdf:
        // Keep existing PDF editor functionality
        return ImprovedPdfViewer(
          document: widget.document!,
          pdfBytes: _fileBytes,
          pdfUrl: _isRemoteFile ? _fileUrl : null,
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

  Widget _buildFileViewerWithFallback() {
    // Simple preview for DOCX and CSV files with external open option
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _fileType == DocumentType.docx ? Icons.description : Icons.table_chart,
            size: 64,
            color: _fileType == DocumentType.docx ? Colors.blue : Colors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'Document Preview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'File: ${widget.document?.name ?? _fileName}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Type: ${_fileType == DocumentType.docx ? 'Word Document' : 'CSV Spreadsheet'}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          
          // Show appropriate action button based on platform and file availability
          if (kIsWeb && _fileBytes != null)
            // Web platform: provide download option
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  if (kIsWeb) {
                    // Web download using blob and anchor element
                    final html.Blob blob = html.Blob([_fileBytes!]);
                    final url = html.Url.createObjectUrlFromBlob(blob);
                    final anchor = html.AnchorElement(href: url)
                      ..setAttribute('download', _fileName ?? 'document')
                      ..click();
                    html.Url.revokeObjectUrl(url);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Download started'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error downloading file: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Download File'),
            )
          else if (!kIsWeb && _filePath != null)
            // Mobile/Desktop: open in external app
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final result = await OpenFile.open(_filePath!);
                  if (result.type != ResultType.done) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not open file: ${result.message}'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening file: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in External App'),
            )
          else
            // Fallback: show unavailable message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(height: 8),
                  Text(
                    'File not available for preview',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Viewer Tab (changed from Editor)
        _buildEditor(),
        
        // Version Management Tab
        widget.document != null 
          ? VersionManagementWidget(document: widget.document!)
          : const Center(child: Text('Version management not available for local files')),
      ],
    );
  }

  String _getTabTitle() {
    switch (_fileType!) {
      case DocumentType.csv:
      case DocumentType.docx:
        return 'Viewer'; // View-only for DOCX and CSV
      case DocumentType.pdf:
        return 'Editor'; // Still editable for PDF
      default:
        return 'Viewer';
    }
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
        title: Text(_fileName ?? 'File Viewer'),
        bottom: widget.document != null 
          ? TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: Icon(_fileType == DocumentType.pdf ? Icons.edit : Icons.visibility),
                  text: _getTabTitle(),
                ),
                const Tab(icon: Icon(Icons.history), text: 'Versions'),
              ],
            )
          : null,
        actions: [
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
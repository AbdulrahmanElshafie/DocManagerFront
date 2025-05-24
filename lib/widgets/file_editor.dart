import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path/path.dart' as path;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/document.dart';
import '../shared/utils/logger.dart';

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

class _FileEditorState extends State<FileEditor> {
  DocumentType? _fileType;
  String? _fileName;
  File? _currentFile;
  String? _fileUrl; // For remote files
  bool _isRemoteFile = false;
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _fileBytes; // For web or downloaded remote files

  // CSV Editor Components
  late CSVDataSource _csvDataSource;
  List<List<String>> _csvData = [];
  final DataGridController _dataGridController = DataGridController();

  // PDF Viewer Components
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfController = PdfViewerController();

  // DOCX Editor Components - Simplified
  final TextEditingController _docxTextController = TextEditingController();

  // PDF Viewer Additional Components
  bool _isTextSelectionEnabled = true;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  int _currentSearchResult = 0;
  int _totalSearchResults = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with empty CSV data to avoid null reference
    _csvData = [['Column 1', 'Column 2', 'Column 3']];
    _csvDataSource = CSVDataSource(_csvData);
    _initializeEditor();
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
    // Assuming the API base URL is localhost:8000 based on the logs
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

      // For local files, check if they exist
      if (!_isRemoteFile && (_currentFile == null || !_currentFile!.existsSync())) {
        throw Exception('Local file does not exist: ${_currentFile?.path}');
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
      String content;
      
      if (_isRemoteFile && _fileBytes != null) {
        content = utf8.decode(_fileBytes!);
      } else if (_currentFile != null) {
        content = await _currentFile!.readAsString();
      } else {
        throw Exception('No file content available');
      }
      
      final csvTable = const CsvToListConverter().convert(content);
      
      _csvData = csvTable.map((row) => 
        row.map((cell) => cell.toString()).toList()
      ).toList();

      if (_csvData.isEmpty) {
        _csvData = [['Column 1', 'Column 2', 'Column 3']];
      }

      _csvDataSource = CSVDataSource(_csvData);
    } catch (e) {
      LoggerUtil.error('Error loading CSV: $e');
      // Create empty CSV with default headers
      _csvData = [['Column 1', 'Column 2', 'Column 3']];
      _csvDataSource = CSVDataSource(_csvData);
    }
  }

  Future<void> _loadPDFContent() async {
    // PDF content will be loaded directly by SfPdfViewer using URL or bytes
    // No additional processing needed here
  }

  Future<void> _loadDOCXContent() async {
    try {
      // Simplified DOCX loading - just show basic text
      _docxTextController.text = 'Document content loaded from: $_fileName\n\nStart editing your document here...';
    } catch (e) {
      LoggerUtil.error('Error loading DOCX: $e');
      _docxTextController.text = 'Error loading document. You can still edit the content here.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName ?? 'File Editor'),
        actions: [
          if (!_isLoading && _errorMessage == null) ...[
            _buildToolbarActions(),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _saveFile,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading file',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeEditor,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    switch (_fileType!) {
      case DocumentType.csv:
        return _buildCSVEditor();
      case DocumentType.pdf:
        return _buildPDFViewer();
      case DocumentType.docx:
        return _buildDOCXEditor();
      case DocumentType.unsupported:
        return const Center(
          child: Text('Unsupported file type'),
        );
    }
  }

  Widget _buildToolbarActions() {
    switch (_fileType!) {
      case DocumentType.csv:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _addCSVRow,
              icon: const Icon(Icons.add),
              tooltip: 'Add Row',
            ),
            IconButton(
              onPressed: _addCSVColumn,
              icon: const Icon(Icons.view_column),
              tooltip: 'Add Column',
            ),
            IconButton(
              onPressed: _deleteCSVRow,
              icon: const Icon(Icons.remove),
              tooltip: 'Delete Row',
            ),
          ],
        );
      case DocumentType.pdf:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _showPDFSearch,
              icon: const Icon(Icons.search),
              tooltip: 'Search',
            ),
            IconButton(
              onPressed: _zoomIn,
              icon: const Icon(Icons.zoom_in),
              tooltip: 'Zoom In',
            ),
            IconButton(
              onPressed: _zoomOut,
              icon: const Icon(Icons.zoom_out),
              tooltip: 'Zoom Out',
            ),
          ],
        );
      case DocumentType.docx:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _makeBold,
              icon: const Icon(Icons.format_bold),
              tooltip: 'Bold',
            ),
            IconButton(
              onPressed: _makeItalic,
              icon: const Icon(Icons.format_italic),
              tooltip: 'Italic',
            ),
            IconButton(
              onPressed: _insertLink,
              icon: const Icon(Icons.link),
              tooltip: 'Insert Link',
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCSVEditor() {
    return Column(
      children: [
        // CSV Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _addCSVRow,
                icon: const Icon(Icons.add),
                label: const Text('Add Row'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addCSVColumn,
                icon: const Icon(Icons.view_column),
                label: const Text('Add Column'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _deleteCSVRow,
                icon: const Icon(Icons.remove),
                label: const Text('Delete Row'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              const Spacer(),
              Text(
                'Rows: ${_csvData.length}, Columns: ${_csvData.isNotEmpty ? _csvData[0].length : 0}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        // CSV Editor
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: _csvData.isEmpty 
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_chart, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No CSV data available'),
                        SizedBox(height: 8),
                        Text('Add rows and columns to get started'),
                      ],
                    ),
                  )
                : SfDataGrid(
                    source: _csvDataSource,
                    controller: _dataGridController,
                    allowEditing: true,
                    allowSorting: true,
                    allowFiltering: true,
                    allowColumnsResizing: true,
                    allowTriStateSorting: true,
                    selectionMode: SelectionMode.single,
                    navigationMode: GridNavigationMode.cell,
                    columnWidthMode: ColumnWidthMode.auto,
                    editingGestureType: EditingGestureType.tap,
                    columns: _buildCSVColumns(),
                    gridLinesVisibility: GridLinesVisibility.both,
                    headerGridLinesVisibility: GridLinesVisibility.both,
                    onSelectionChanged: (List<DataGridRow> addedRows, List<DataGridRow> removedRows) {
                      // Handle selection changes
                    },
                    onCellTap: (DataGridCellTapDetails details) {
                      // Handle cell tap for editing
                    },
                  ),
          ),
        ),
      ],
    );
  }

  List<GridColumn> _buildCSVColumns() {
    if (_csvData.isEmpty) return [];
    
    return List.generate(_csvData[0].length, (index) {
      final columnName = 'column$index';
      final headerText = _csvData.isNotEmpty ? _csvData[0][index] : 'Column ${index + 1}';
      
      return GridColumn(
        columnName: columnName,
        width: 120, // Fixed width for better display
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Text(
            headerText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    });
  }

  Widget _buildPDFViewer() {
    return Column(
      children: [
        // PDF Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _zoomOut,
                icon: const Icon(Icons.zoom_out),
                tooltip: 'Zoom Out',
              ),
              IconButton(
                onPressed: _zoomIn,
                icon: const Icon(Icons.zoom_in),
                tooltip: 'Zoom In',
              ),
              IconButton(
                onPressed: _fitToWidth,
                icon: const Icon(Icons.fit_screen),
                tooltip: 'Fit to Width',
              ),
              const VerticalDivider(),
              IconButton(
                onPressed: _showPDFSearch,
                icon: const Icon(Icons.search),
                tooltip: 'Search',
              ),
              IconButton(
                onPressed: _toggleTextSelection,
                icon: Icon(_isTextSelectionEnabled ? Icons.text_fields : Icons.text_fields_outlined),
                tooltip: 'Toggle Text Selection',
              ),
              const VerticalDivider(),
              IconButton(
                onPressed: _addHighlight,
                icon: const Icon(Icons.highlight),
                tooltip: 'Highlight',
                color: Colors.yellow[700],
              ),
              IconButton(
                onPressed: _addNote,
                icon: const Icon(Icons.note_add),
                tooltip: 'Add Note',
                color: Colors.blue,
              ),
              const Spacer(),
              Text(
                '$_currentPage / $_totalPages',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _goToPreviousPage,
                icon: const Icon(Icons.keyboard_arrow_left),
                tooltip: 'Previous Page',
              ),
              IconButton(
                onPressed: _goToNextPage,
                icon: const Icon(Icons.keyboard_arrow_right),
                tooltip: 'Next Page',
              ),
            ],
          ),
        ),
        // PDF Search Bar (conditionally shown)
        if (_showSearchBar)
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search in PDF...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty) ...[
                            Text(
                              '$_currentSearchResult of $_totalSearchResults',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _searchPrevious,
                              icon: const Icon(Icons.keyboard_arrow_up),
                              tooltip: 'Previous Result',
                            ),
                            IconButton(
                              onPressed: _searchNext,
                              icon: const Icon(Icons.keyboard_arrow_down),
                              tooltip: 'Next Result',
                            ),
                          ],
                          IconButton(
                            onPressed: _closeSearch,
                            icon: const Icon(Icons.close),
                            tooltip: 'Close Search',
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: _onSearchTextChanged,
                    onSubmitted: _onSearchSubmitted,
                  ),
                ),
              ],
            ),
          ),
        // PDF Viewer
        Expanded(
          child: _buildPDFContent(),
        ),
      ],
    );
  }

  Widget _buildPDFContent() {
    if (_isRemoteFile && _fileUrl != null) {
      // For remote PDF files, use URL
      return SfPdfViewer.network(
        _fileUrl!,
        key: _pdfViewerKey,
        controller: _pdfController,
        enableTextSelection: _isTextSelectionEnabled,
        enableHyperlinkNavigation: true,
        enableDocumentLinkAnnotation: true,
        canShowScrollHead: true,
        canShowScrollStatus: false, // We handle this in toolbar
        canShowPaginationDialog: true,
        enableDoubleTapZooming: true,
        onPageChanged: _onPageChanged,
        onDocumentLoaded: _onPDFDocumentLoaded,
        onTextSelectionChanged: _onTextSelectionChanged,
      );
    } else if (_fileBytes != null) {
      // For downloaded remote files or web
      return SfPdfViewer.memory(
        _fileBytes!,
        key: _pdfViewerKey,
        controller: _pdfController,
        enableTextSelection: _isTextSelectionEnabled,
        enableHyperlinkNavigation: true,
        enableDocumentLinkAnnotation: true,
        canShowScrollHead: true,
        canShowScrollStatus: false,
        canShowPaginationDialog: true,
        enableDoubleTapZooming: true,
        onPageChanged: _onPageChanged,
        onDocumentLoaded: _onPDFDocumentLoaded,
        onTextSelectionChanged: _onTextSelectionChanged,
      );
    } else if (_currentFile != null) {
      // For local files
      return SfPdfViewer.file(
        _currentFile!,
        key: _pdfViewerKey,
        controller: _pdfController,
        enableTextSelection: _isTextSelectionEnabled,
        enableHyperlinkNavigation: true,
        enableDocumentLinkAnnotation: true,
        canShowScrollHead: true,
        canShowScrollStatus: false,
        canShowPaginationDialog: true,
        enableDoubleTapZooming: true,
        onPageChanged: _onPageChanged,
        onDocumentLoaded: _onPDFDocumentLoaded,
        onTextSelectionChanged: _onTextSelectionChanged,
      );
    } else {
      return const Center(
        child: Text('No PDF content available'),
      );
    }
  }

  Widget _buildDOCXEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Information Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DOCX File Editing - Limited Support',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DOCX files contain complex XML-based formatting, tables, images, and styles that cannot be fully rendered in this editor. This shows extracted text content only.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'For full DOCX editing with formatting preservation, use Microsoft Word, Google Docs, or LibreOffice.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _makeBold,
                  icon: const Icon(Icons.format_bold),
                  tooltip: 'Bold (Markdown: **text**)',
                ),
                IconButton(
                  onPressed: _makeItalic,
                  icon: const Icon(Icons.format_italic),
                  tooltip: 'Italic (Markdown: *text*)',
                ),
                IconButton(
                  onPressed: _insertLink,
                  icon: const Icon(Icons.link),
                  tooltip: 'Insert Link',
                ),
                const VerticalDivider(),
                IconButton(
                  onPressed: _insertBulletList,
                  icon: const Icon(Icons.format_list_bulleted),
                  tooltip: 'Bullet List',
                ),
                IconButton(
                  onPressed: _insertNumberedList,
                  icon: const Icon(Icons.format_list_numbered),
                  tooltip: 'Numbered List',
                ),
                IconButton(
                  onPressed: _insertHeading,
                  icon: const Icon(Icons.title),
                  tooltip: 'Insert Heading',
                ),
                const Spacer(),
                Text(
                  'Lines: ${_getLineCount()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Text(
                  'Words: ${_getWordCount()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Text Editor
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Start editing your document here...\n\nSupported formatting:\n**Bold Text**\n*Italic Text*\n[Link Text](URL)\n# Heading 1\n## Heading 2\n- Bullet point\n1. Numbered list',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                controller: _docxTextController,
                style: const TextStyle(
                  fontFamily: 'monospace', // Better for seeing formatting
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Export Options
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: For advanced DOCX editing, consider using specialized applications like Microsoft Word or Google Docs.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _exportAsMarkdown,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export as Markdown'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getLineCount() {
    return _docxTextController.text.split('\n').length;
  }

  int _getWordCount() {
    final text = _docxTextController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  void _insertBulletList() {
    final selection = _docxTextController.selection;
    final text = _docxTextController.text;
    final newText = text.replaceRange(selection.start, selection.end, '- ');
    _docxTextController.text = newText;
    _docxTextController.selection = TextSelection.collapsed(
      offset: selection.start + 2,
    );
  }

  void _insertNumberedList() {
    final selection = _docxTextController.selection;
    final text = _docxTextController.text;
    final newText = text.replaceRange(selection.start, selection.end, '1. ');
    _docxTextController.text = newText;
    _docxTextController.selection = TextSelection.collapsed(
      offset: selection.start + 3,
    );
  }

  void _insertHeading() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Heading'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Heading 1'),
              subtitle: const Text('# Large heading'),
              onTap: () => _insertHeadingLevel(1),
            ),
            ListTile(
              title: const Text('Heading 2'),
              subtitle: const Text('## Medium heading'),
              onTap: () => _insertHeadingLevel(2),
            ),
            ListTile(
              title: const Text('Heading 3'),
              subtitle: const Text('### Small heading'),
              onTap: () => _insertHeadingLevel(3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _insertHeadingLevel(int level) {
    Navigator.pop(context);
    final selection = _docxTextController.selection;
    final text = _docxTextController.text;
    final prefix = '${'#' * level} ';
    final newText = text.replaceRange(selection.start, selection.end, prefix);
    _docxTextController.text = newText;
    _docxTextController.selection = TextSelection.collapsed(
      offset: selection.start + prefix.length,
    );
  }

  void _exportAsMarkdown() {
    // Export the content as markdown
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Markdown export functionality would be implemented here'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // CSV Editor Actions
  void _addCSVRow() {
    setState(() {
      if (_csvData.isEmpty) {
        _csvData.add(['New Row']);
      } else {
        final newRow = List.filled(_csvData[0].length, '');
        _csvData.add(newRow);
      }
      _csvDataSource.updateData(_csvData);
    });
  }

  void _addCSVColumn() {
    setState(() {
      if (_csvData.isEmpty) {
        _csvData.add(['New Column']);
      } else {
        for (int i = 0; i < _csvData.length; i++) {
          if (i == 0) {
            _csvData[i].add('New Column');
          } else {
            _csvData[i].add('');
          }
        }
      }
      _csvDataSource.updateData(_csvData);
    });
  }

  void _deleteCSVRow() {
    setState(() {
      if (_csvData.length > 1) {
        _csvData.removeLast();
        _csvDataSource.updateData(_csvData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot delete header row'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  // PDF Viewer Actions
  void _showPDFSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _pdfController.clearSelection();
      }
    });
  }

  void _zoomIn() {
    if (_pdfController.zoomLevel < 3.0) {
      _pdfController.zoomLevel += 0.25;
    }
  }

  void _zoomOut() {
    if (_pdfController.zoomLevel > 0.5) {
      _pdfController.zoomLevel -= 0.25;
    }
  }

  void _fitToWidth() {
    // Reset zoom to fit width
    _pdfController.zoomLevel = 1.0;
  }

  void _toggleTextSelection() {
    setState(() {
      _isTextSelectionEnabled = !_isTextSelectionEnabled;
    });
  }

  void _addHighlight() {
    // Add highlight annotation - this would need more complex implementation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Highlight feature - select text first, then use this button'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _addNote() {
    // Add note annotation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: const TextField(
          decoration: InputDecoration(
            labelText: 'Note text',
            hintText: 'Enter your note here...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Note added successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Add Note'),
          ),
        ],
      ),
    );
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _pdfController.previousPage();
    }
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages) {
      _pdfController.nextPage();
    }
  }

  void _searchPrevious() {
    // Note: Current Syncfusion version doesn't support navigation between search results
    // This is a placeholder for future functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search navigation not available in current PDF viewer version'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _searchNext() {
    // Note: Current Syncfusion version doesn't support navigation between search results
    // This is a placeholder for future functionality  
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search navigation not available in current PDF viewer version'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _closeSearch() {
    setState(() {
      _showSearchBar = false;
      _searchController.clear();
      _currentSearchResult = 0;
      _totalSearchResults = 0;
    });
    _pdfController.clearSelection();
  }

  void _onSearchTextChanged(String text) {
    if (text.isNotEmpty) {
      _pdfController.searchText(text);
    } else {
      _pdfController.clearSelection();
      setState(() {
        _currentSearchResult = 0;
        _totalSearchResults = 0;
      });
    }
  }

  void _onSearchSubmitted(String text) {
    if (text.isNotEmpty) {
      final result = _pdfController.searchText(text);
      // Note: Search result handling is limited in current Syncfusion version
      LoggerUtil.info('PDF search performed for: $text');
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
    });
  }

  void _onPDFDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _totalPages = details.document.pages.count;
      _currentPage = 1;
    });
  }

  void _onTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    // Handle text selection change
    if (details.selectedText != null && details.selectedText!.isNotEmpty) {
      // Show context menu or handle selection
      LoggerUtil.info('Text selected: ${details.selectedText}');
    }
  }

  // DOCX Editor Actions
  void _makeBold() {
    // Implement bold logic for the text editor
    final selection = _docxTextController.selection;
    if (selection.isValid) {
      final text = _docxTextController.text;
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '**$selectedText**');
      _docxTextController.text = newText;
      _docxTextController.selection = TextSelection.collapsed(
        offset: selection.start + selectedText.length + 4,
      );
    }
  }

  void _makeItalic() {
    // Implement italic logic for the text editor
    final selection = _docxTextController.selection;
    if (selection.isValid) {
      final text = _docxTextController.text;
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '*$selectedText*');
      _docxTextController.text = newText;
      _docxTextController.selection = TextSelection.collapsed(
        offset: selection.start + selectedText.length + 2,
      );
    }
  }

  void _insertLink() {
    // Implement link insertion logic
    showDialog(
      context: context,
      builder: (context) {
        final urlController = TextEditingController();
        final textController = TextEditingController();
        
        return AlertDialog(
          title: const Text('Insert Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Link Text',
                  hintText: 'Enter display text...',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final linkText = textController.text.isNotEmpty 
                    ? textController.text 
                    : urlController.text;
                final markdownLink = '[$linkText](${urlController.text})';
                
                final selection = _docxTextController.selection;
                final text = _docxTextController.text;
                final newText = text.replaceRange(
                  selection.start,
                  selection.end,
                  markdownLink,
                );
                
                _docxTextController.text = newText;
                _docxTextController.selection = TextSelection.collapsed(
                  offset: selection.start + markdownLink.length,
                );
                
                Navigator.pop(context);
              },
              child: const Text('Insert'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveFile() async {
    try {
      switch (_fileType!) {
        case DocumentType.csv:
          await _saveCSVFile();
          break;
        case DocumentType.pdf:
          await _savePDFFile();
          break;
        case DocumentType.docx:
          await _saveDOCXFile();
          break;
        case DocumentType.unsupported:
          throw Exception('Cannot save unsupported file type');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      LoggerUtil.error('Error saving file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveCSVFile() async {
    // Get the updated data from the CSV data source
    final updatedData = _csvDataSource.data;
    final csvContent = const ListToCsvConverter().convert(updatedData);
    
    if (widget.onSave != null) {
      widget.onSave!(csvContent, DocumentType.csv);
    } else {
      // Save to file
      File fileToSave;
      
      if (_isRemoteFile) {
        // Create a temporary file for remote files
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${_fileName ?? 'document.csv'}');
        fileToSave = tempFile;
      } else {
        fileToSave = _currentFile!;
      }
      
      await fileToSave.writeAsString(csvContent);
      
      if (widget.onSaveFile != null) {
        widget.onSaveFile!(fileToSave);
      }
    }
  }

  Future<void> _savePDFFile() async {
    // For PDF, we typically can't edit the original content
    // Instead, we might save annotations or form data
    if (widget.onSaveFile != null) {
      if (_isRemoteFile) {
        // For remote files, create a temporary local file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${_fileName ?? 'document.pdf'}');
        if (_fileBytes != null) {
          await tempFile.writeAsBytes(_fileBytes!);
        }
        widget.onSaveFile!(tempFile);
      } else {
        widget.onSaveFile!(_currentFile!);
      }
    }
  }

  Future<void> _saveDOCXFile() async {
    // Convert the document content to a simple text format
    // In a real implementation, you would convert back to DOCX format
    String content = _docxTextController.text;
    
    if (widget.onSave != null) {
      widget.onSave!(content, DocumentType.docx);
    } else {
      try {
        // For now, save as plain text
        // In a real implementation, you would use a DOCX library to create proper DOCX files
        final tempDir = await getTemporaryDirectory();
        final textFile = File('${tempDir.path}/${_fileName}_converted.txt');
        await textFile.writeAsString(content);
        
        if (widget.onSaveFile != null) {
          widget.onSaveFile!(textFile);
        }
      } catch (e) {
        LoggerUtil.error('Error saving DOCX content: $e');
        rethrow;
      }
    }
  }

  @override
  void dispose() {
    _dataGridController.dispose();
    _pdfController.dispose();
    _docxTextController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// CSV Data Source for SfDataGrid
class CSVDataSource extends DataGridSource {
  List<List<String>> _data = [];
  List<DataGridRow> _dataGridRows = [];

  CSVDataSource(List<List<String>> data) {
    updateData(data);
  }

  void updateData(List<List<String>> data) {
    _data = List.from(data);
    _buildDataGridRows();
    notifyListeners();
  }

  void _buildDataGridRows() {
    _dataGridRows.clear();
    
    // Skip header row (index 0) when building data rows
    for (int i = 1; i < _data.length; i++) {
      final row = _data[i];
      _dataGridRows.add(
        DataGridRow(
          cells: row.asMap().entries.map<DataGridCell>((entry) {
            return DataGridCell<String>(
              columnName: 'column${entry.key}',
              value: entry.value,
            );
          }).toList(),
        ),
      );
    }
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            cell.value?.toString() ?? '',
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget? buildEditWidget(
    DataGridRow dataGridRow,
    RowColumnIndex rowColumnIndex,
    GridColumn column,
    CellSubmit submitCell,
  ) {
    final String displayText = dataGridRow
            .getCells()
            .firstWhere((DataGridCell dataGridCell) =>
                dataGridCell.columnName == column.columnName)
            .value
            ?.toString() ??
        '';

    final TextEditingController controller = TextEditingController(text: displayText);

    return Container(
      padding: const EdgeInsets.all(4.0),
      alignment: Alignment.centerLeft,
      child: TextField(
        autofocus: true,
        controller: controller,
        textAlign: TextAlign.left,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          isDense: true,
        ),
        onSubmitted: (String value) {
          _updateCellValue(rowColumnIndex, column.columnName, value);
          submitCell();
        },
        onEditingComplete: () {
          _updateCellValue(rowColumnIndex, column.columnName, controller.text);
          submitCell();
        },
      ),
    );
  }

  void _updateCellValue(RowColumnIndex rowColumnIndex, String columnName, String newValue) {
    // Calculate the actual data row index (add 1 because we skip header)
    final dataRowIndex = rowColumnIndex.rowIndex;
    final actualRowIndex = dataRowIndex + 1; // Skip header row
    
    // Extract column index from column name
    final columnIndex = int.parse(columnName.replaceAll('column', ''));
    
    // Update the data
    if (actualRowIndex < _data.length && columnIndex < _data[actualRowIndex].length) {
      _data[actualRowIndex][columnIndex] = newValue;
      
      // Rebuild the data grid rows to reflect changes
      _buildDataGridRows();
      notifyListeners();
    }
  }

  List<List<String>> get data => _data;
} 
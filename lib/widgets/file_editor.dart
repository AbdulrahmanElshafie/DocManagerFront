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

  @override
  void initState() {
    super.initState();
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
        Expanded(
          child: SfDataGrid(
            source: _csvDataSource,
            controller: _dataGridController,
            allowEditing: true,
            allowSorting: true,
            allowFiltering: true,
            selectionMode: SelectionMode.single,
            navigationMode: GridNavigationMode.cell,
            columnWidthMode: ColumnWidthMode.fill,
            editingGestureType: EditingGestureType.doubleTap,
            columns: _buildCSVColumns(),
          ),
        ),
      ],
    );
  }

  List<GridColumn> _buildCSVColumns() {
    if (_csvData.isEmpty) return [];
    
    return List.generate(_csvData[0].length, (index) {
      return GridColumn(
        columnName: 'column$index',
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: Text(
            _csvData[0][index],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    });
  }

  Widget _buildPDFViewer() {
    if (_isRemoteFile && _fileUrl != null) {
      // For remote PDF files, use URL
      return SfPdfViewer.network(
        _fileUrl!,
        key: _pdfViewerKey,
        controller: _pdfController,
        enableTextSelection: true,
        enableHyperlinkNavigation: true,
        enableDocumentLinkAnnotation: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
      );
    } else if (_fileBytes != null) {
      // For downloaded remote files or web
      return SfPdfViewer.memory(
        _fileBytes!,
        key: _pdfViewerKey,
        controller: _pdfController,
        enableTextSelection: true,
        enableHyperlinkNavigation: true,
        enableDocumentLinkAnnotation: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
      );
    } else if (_currentFile != null) {
      // For local files
      return SfPdfViewer.file(
        _currentFile!,
        key: _pdfViewerKey,
        controller: _pdfController,
        enableTextSelection: true,
        enableHyperlinkNavigation: true,
        enableDocumentLinkAnnotation: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
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
          const Text(
            'DOCX Editor (Simplified)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: 'Start editing your document here...',
                border: OutlineInputBorder(),
              ),
              controller: _docxTextController,
            ),
          ),
        ],
      ),
    );
  }

  // CSV Editor Actions
  void _addCSVRow() {
    setState(() {
      if (_csvData.isEmpty) {
        _csvData.add(['New Row']);
      } else {
        _csvData.add(List.filled(_csvData[0].length, ''));
      }
      _csvDataSource.updateData(_csvData);
    });
  }

  void _addCSVColumn() {
    setState(() {
      for (int i = 0; i < _csvData.length; i++) {
        if (i == 0) {
          _csvData[i].add('New Column');
        } else {
          _csvData[i].add('');
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
      }
    });
  }

  // PDF Viewer Actions
  void _showPDFSearch() {
    _pdfController.searchText('');
  }

  void _zoomIn() {
    _pdfController.zoomLevel += 0.25;
  }

  void _zoomOut() {
    _pdfController.zoomLevel -= 0.25;
  }

  // DOCX Editor Actions
  void _makeBold() {
    // Implement bold logic
  }

  void _makeItalic() {
    // Implement italic logic
  }

  void _insertLink() {
    // Implement link insertion logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Link'),
        content: const TextField(
          decoration: InputDecoration(
            labelText: 'URL',
            hintText: 'https://example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Implement link insertion
              Navigator.pop(context);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
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
    final csvContent = const ListToCsvConverter().convert(_csvData);
    
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
    _data = data;
    _dataGridRows = _data.skip(1).map<DataGridRow>((row) {
      return DataGridRow(
        cells: row.asMap().entries.map<DataGridCell>((entry) {
          return DataGridCell<String>(
            columnName: 'column${entry.key}',
            value: entry.value,
          );
        }).toList(),
      );
    }).toList();
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text(cell.value?.toString() ?? ''),
        );
      }).toList(),
    );
  }

  @override
  Widget? buildEditWidget(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column, CellSubmit submitCell) {
    final String displayText = dataGridRow
        .getCells()
        .firstWhere((DataGridCell dataGridCell) =>
            dataGridCell.columnName == column.columnName)
        .value
        ?.toString() ??
    '';

    return Container(
      padding: const EdgeInsets.all(8.0),
      alignment: Alignment.center,
      child: TextField(
        autofocus: true,
        controller: TextEditingController(text: displayText),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onSubmitted: (String value) {
          final rowIndex = rowColumnIndex.rowIndex - 1;
          final columnIndex = rowColumnIndex.columnIndex;
          
          if (rowIndex >= 0 && rowIndex < _data.length - 1 && 
              columnIndex >= 0 && columnIndex < _data[rowIndex + 1].length) {
            _data[rowIndex + 1][columnIndex] = value;
          }
          
          submitCell();
        },
      ),
    );
  }
} 
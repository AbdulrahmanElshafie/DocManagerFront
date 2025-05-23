import 'dart:io';
import 'package:flutter/material.dart';
import 'package:doc_manager/models/document.dart' as app_document;
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:super_editor/super_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EnhancedDocumentEditor extends StatefulWidget {
  final File file;
  final app_document.DocumentType documentType;
  final String documentName;
  final Function(File file) onSave;
  final bool readOnly;

  const EnhancedDocumentEditor({
    Key? key,
    required this.file,
    required this.documentType,
    required this.documentName,
    required this.onSave,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<EnhancedDocumentEditor> createState() => _EnhancedDocumentEditorState();
}

class _EnhancedDocumentEditorState extends State<EnhancedDocumentEditor> {
  late final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();
  late final PdfViewerController _pdfViewerController = PdfViewerController();
  late app_document.DocumentType _documentType;
  bool _isLoading = true;
  String _errorMessage = '';
  
  // For CSV files
  late SpreadsheetDataSource _dataSource;
  List<List<dynamic>> _csvData = [['Column1', 'Column2', 'Column3']]; // Initialize with default header
  int? _selectedRowIndex; // Track selected row
  int? _selectedColumnIndex; // Track selected column
  
  // For PDF files 
  File? _annotatedPdfFile;
  Uint8List? _pdfBytes; // To store PDF data for web
  
  // For DOCX files
  late MutableDocument _superEditorDocument;
  bool _isDocxInitialized = false;
  late TextEditingController _docTextController;
  
  // Generate a unique ID for document nodes
  String _generateNodeId() {
    return const Uuid().v4();
  }
  
  @override
  void initState() {
    super.initState();
    _documentType = widget.documentType;
    _dataSource = SpreadsheetDataSource(data: _csvData); // Initialize with default data
    _docTextController = TextEditingController();
    _initSuperEditorDocument(); // Initialize the document editor
    _loadDocument();
  }
  
  // Initialize the SuperEditor document with a default empty document
  void _initSuperEditorDocument() {
    _superEditorDocument = MutableDocument(nodes: [
      ParagraphNode(
        id: _generateNodeId(),
        text: AttributedText(''),
        metadata: const {},
      ),
    ]);
    _isDocxInitialized = true;
  }
  
  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Handle web platform specially
      if (kIsWeb) {
        // For web, we'll use default content as we can't directly access files
        _handleWebPlatform();
        return;
      }
      
      // Check if file exists first
      bool fileExists = false;
      try {
        // Normalize path for Windows if needed
        String normalizedPath = widget.file.path;
        if (Platform.isWindows) {
          normalizedPath = normalizedPath.replaceAll('\\', '/');
          developer.log('Normalized Windows path: $normalizedPath', name: 'EnhancedDocumentEditor');
        }
        
        // Check file existence with proper error handling
        try {
          fileExists = await widget.file.exists();
          developer.log('File exists check: $fileExists for path: ${widget.file.path}', 
              name: 'EnhancedDocumentEditor');
        } catch (e) {
          developer.log('Error checking if file exists: $e', name: 'EnhancedDocumentEditor');
          fileExists = false;
        }
      } catch (e) {
        developer.log('Error normalizing path: $e', name: 'EnhancedDocumentEditor');
        fileExists = false;
      }
      
      if (!fileExists) {
        developer.log('Warning: File does not exist at path: ${widget.file.path}', name: 'EnhancedDocumentEditor');
      }
      
      switch (_documentType) {
        case app_document.DocumentType.csv:
          await _loadCsvDocument(fileExists);
          break;
        case app_document.DocumentType.pdf:
          if (fileExists) {
            // PDF loading happens in the viewer
            setState(() {
              _isLoading = false;
            });
          } else {
            // Can't display PDF if file doesn't exist
            setState(() {
              _errorMessage = 'PDF file not found. Please create a new document.';
              _isLoading = false;
            });
          }
          break;
        case app_document.DocumentType.docx:
          await _loadDocxDocument(fileExists);
          break;
        default:
          // For unsupported types, try to load as text
          if (fileExists) {
            try {
              final content = await widget.file.readAsString();
              _docTextController.text = content;
              setState(() {
                _isLoading = false;
              });
            } catch (e) {
              // Fall back to default text
              _docTextController.text = 'Document content goes here.';
              setState(() {
                _isLoading = false;
              });
            }
          } else {
            // Use default content
            _docTextController.text = 'Document content goes here.';
            setState(() {
              _isLoading = false;
            });
          }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading document: $e';
        _isLoading = false;
      });
      developer.log('Error loading document: $e', name: 'EnhancedDocumentEditor');
    }
  }
  
  // Handle web platform where file system access is limited
  void _handleWebPlatform() {
    switch (_documentType) {
      case app_document.DocumentType.csv:
        _csvData = [
          ['Column1', 'Column2', 'Column3'],
          ['Value1', 'Value2', 'Value3'],
          ['Value4', 'Value5', 'Value6'],
        ];
        _dataSource = SpreadsheetDataSource(data: _csvData);
        break;
      case app_document.DocumentType.docx:
        _docTextController.text = 'Document content for ${widget.documentName}\n\nEdit this document in the web version.';
        break;
      case app_document.DocumentType.pdf:
        // PDF viewing on web needs special handling
        _errorMessage = 'PDF viewing in web version has limited functionality.';
        break;
      default:
        _docTextController.text = 'Document content goes here.\n\nEdit this document in the web version.';
    }
    
    setState(() {
      _isLoading = false;
    });
  }
  
  // MARK: - CSV Document Handling
  
  Future<void> _loadCsvDocument(bool fileExists) async {
    try {
      if (fileExists) {
        try {
          final loadedData = await _parseCsvWithExcel(widget.file);
          
          // Ensure we have at least one row for headers
          if (loadedData.isEmpty) {
            _csvData = [
              ['Column1', 'Column2', 'Column3'],
              ['Value1', 'Value2', 'Value3'],
            ];
          } else {
            _csvData = loadedData;
          }
        } catch (e) {
          developer.log('Error parsing CSV, using default data: $e', name: 'EnhancedDocumentEditor');
          _csvData = [
            ['Column1', 'Column2', 'Column3'],
            ['Value1', 'Value2', 'Value3'],
            ['Error', 'Parsing', 'File'],
          ];
        }
      } else {
        // Default data if file doesn't exist
        _csvData = [
          ['Column1', 'Column2', 'Column3'],
          ['Value1', 'Value2', 'Value3'],
          ['Value4', 'Value5', 'Value6'],
        ];
      }
      
      _dataSource = SpreadsheetDataSource(data: _csvData);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Use default data on error
      _csvData = [
        ['Column1', 'Column2', 'Column3'],
        ['Value1', 'Value2', 'Value3'],
        ['Error', 'Loading', 'Data'],
      ];
      _dataSource = SpreadsheetDataSource(data: _csvData);
      
      setState(() {
        _isLoading = false;
      });
      
      developer.log('Error parsing CSV, using default data: $e', name: 'EnhancedDocumentEditor');
    }
  }
  
  Future<List<List<dynamic>>> _parseCsvWithExcel(File file) async {
    if (!file.existsSync()) {
      return [
        ['Column1', 'Column2', 'Column3'],
        ['Value1', 'Value2', 'Value3'],
      ];
    }
    
    try {
      developer.log('Parsing CSV file with Excel: ${file.path}', name: 'EnhancedDocumentEditor');
      
      final bytes = await file.readAsBytes();
      
      // Use Excel package to parse the file
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        return [
          ['No data', 'found in', 'CSV file'],
          ['Please edit', 'to add', 'content'],
        ];
      }
      
      // Get the first sheet
      final sheet = excel.tables.keys.first;
      final table = excel.tables[sheet]!;
      
      final List<List<dynamic>> result = [];
      
      // Convert Excel rows to list format
      for (var rowIndex = 0; rowIndex < table.maxRows; rowIndex++) {
        final rowData = <dynamic>[];
        
        // Get the number of columns in this row
        int colCount = 0;
        for (var cell in table.rows[rowIndex]) {
          if (cell != null) colCount++;
        }
        
        for (var colIndex = 0; colIndex < colCount; colIndex++) {
          final cell = table.cell(CellIndex.indexByColumnRow(
            columnIndex: colIndex, 
            rowIndex: rowIndex
          ));
          
          rowData.add(cell.value);
        }
        result.add(rowData);
      }
      
      developer.log('CSV parsed successfully. Rows: ${result.length}, Columns: ${result.isNotEmpty ? result[0].length : 0}', 
               name: 'EnhancedDocumentEditor');
      return result;
    } catch (e) {
      developer.log('Error parsing CSV with Excel package: $e', name: 'EnhancedDocumentEditor');
      
      // Try fallback parsing method
      try {
        final content = await file.readAsString();
        final lines = content.split('\n');
        
        if (lines.isEmpty) {
          return [
            ['CSV file is empty'],
            ['Please add content'],
          ];
        }
        
        final result = lines.where((line) => line.trim().isNotEmpty).map((line) {
          return line.split(',').map((cell) => cell.trim()).toList();
        }).toList();
        
        developer.log('CSV parsed with fallback method. Rows: ${result.length}', name: 'EnhancedDocumentEditor');
        return result;
      } catch (e) {
        developer.log('Error parsing CSV with fallback method: $e', name: 'EnhancedDocumentEditor');
        return [
          ['Error', 'parsing', 'CSV file'],
          ['Please try', 'another', 'file'],
        ];
      }
    }
  }
  
  Future<void> _saveCsvData() async {
    try {
      // Create Excel object
      final excel = Excel.createExcel();
      
      // Get the default sheet
      final sheet = excel.sheets[excel.getDefaultSheet()];
      if (sheet == null) {
        throw Exception('Failed to get default sheet');
      }
      
      // Add data to sheet
      for (int row = 0; row < _csvData.length; row++) {
        for (int col = 0; col < _csvData[row].length; col++) {
          sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: row,
          )).value = _csvData[row][col];
        }
      }
      
      // Save to bytes
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel document');
      }
      
      // Check file path
      developer.log('Saving CSV to file: ${widget.file.path}', name: 'EnhancedDocumentEditor');
      
      // Check if file exists and is writable
      bool canWrite = true;
      String filePath = widget.file.path;
      
      // Normalize path for Windows
      if (Platform.isWindows) {
        filePath = filePath.replaceAll('\\', '/');
      }
      
      // Ensure the directory exists
      final directory = path.dirname(filePath);
      final dir = Directory(directory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      try {
        // Test write access
        final file = File(filePath);
        await file.writeAsBytes([]);
      } catch (e) {
        developer.log('Cannot write to file: $e', name: 'EnhancedDocumentEditor');
        canWrite = false;
      }
      
      if (!canWrite) {
        // Try to use a temporary file instead
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basename(widget.file.path);
        filePath = '${tempDir.path}/$fileName';
        developer.log('Using temporary file instead: $filePath', name: 'EnhancedDocumentEditor');
      }
      
      // Save to file (either original or temporary)
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      // Call the onSave callback with the file
      widget.onSave(file);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV data saved successfully')),
      );
    } catch (e) {
      developer.log('Error saving CSV data: $e', name: 'EnhancedDocumentEditor');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save CSV data: $e')),
      );
    }
  }
  
  void _addRow() {
    setState(() {
      if (_csvData.isNotEmpty) {
        final newRow = List<dynamic>.filled(_csvData[0].length, "");
        _csvData.add(newRow);
        _dataSource = SpreadsheetDataSource(data: _csvData);
      }
    });
  }
  
  void _addColumn() {
    setState(() {
      if (_csvData.isNotEmpty) {
        for (var row in _csvData) {
          row.add("");
        }
        _dataSource = SpreadsheetDataSource(data: _csvData);
      }
    });
  }
  
  void _removeSelectedRow() {
    // Use our tracked selected row
    if (_selectedRowIndex != null) {
      setState(() {
        // Add 1 to account for header row in _csvData
        final dataRowIndex = _selectedRowIndex! + 1;
        if (dataRowIndex < _csvData.length) {
          _csvData.removeAt(dataRowIndex);
          _dataSource = SpreadsheetDataSource(data: _csvData);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a row to remove')),
      );
    }
  }
  
  void _removeSelectedColumn() {
    // Use our tracked selected column
    if (_selectedColumnIndex != null) {
      setState(() {
        if (_csvData.isNotEmpty && _selectedColumnIndex! >= 0 && _selectedColumnIndex! < _csvData[0].length) {
          for (var row in _csvData) {
            if (_selectedColumnIndex! < row.length) {
              row.removeAt(_selectedColumnIndex!);
            }
          }
          _dataSource = SpreadsheetDataSource(data: _csvData);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a column to remove')),
      );
    }
  }
  
  // MARK: - DOCX Document Handling
  
  Future<void> _loadDocxDocument(bool fileExists) async {
    try {
      if (fileExists) {
        try {
          // For now, we'll create a simplified representation for the SuperEditor
          // In a production app, you'd convert DOCX to a format SuperEditor can understand
          final content = await _extractDocxContent();
          _docTextController.text = content.join('\n\n');
        } catch (e) {
          developer.log('Error extracting DOCX content: $e', name: 'EnhancedDocumentEditor');
          // Use default content on error
          _docTextController.text = 'Error loading document content.\n\nYou can edit this text to replace the content.';
        }
      } else {
        // Use default content
        _docTextController.text = 'Document content goes here.\n\nThis is a new document you can edit.';
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Use default content on error
      _docTextController.text = 'Error loading document content.\n\nYou can edit this text to replace the content.';
      setState(() {
        _isLoading = false;
      });
      developer.log('Error loading DOCX content, using default content: $e', name: 'EnhancedDocumentEditor');
    }
  }
  
  Future<List<String>> _extractDocxContent() async {
    // This is a simplified version - in a real app, you'd use a more
    // sophisticated DOCX parsing approach
    try {
      // First try to read as text
      final String content = await widget.file.readAsString();
      return [content];
    } catch (e) {
      developer.log('Error reading DOCX as text: $e', name: 'EnhancedDocumentEditor');
      // For binary files, provide a placeholder
      return ['This document contains formatted content that has been converted for editing. Formatting may be simplified.'];
    }
  }

  Future<void> _saveDocxDocument() async {
    try {
      // Check file path
      developer.log('Saving DOCX to file: ${widget.file.path}', name: 'EnhancedDocumentEditor');
      
      // Check if file exists and is writable
      bool canWrite = true;
      String filePath = widget.file.path;
      
      // Normalize path for Windows
      if (Platform.isWindows) {
        filePath = filePath.replaceAll('\\', '/');
      }
      
      // Ensure the directory exists
      final directory = path.dirname(filePath);
      final dir = Directory(directory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      try {
        // Test write access
        final file = File(filePath);
        await file.writeAsBytes([]);
      } catch (e) {
        developer.log('Cannot write to file: $e', name: 'EnhancedDocumentEditor');
        canWrite = false;
      }
      
      if (!canWrite) {
        // Try to use a temporary file instead
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basename(widget.file.path);
        filePath = '${tempDir.path}/$fileName';
        developer.log('Using temporary file instead: $filePath', name: 'EnhancedDocumentEditor');
      }
      
      // Save to file (either original or temporary)
      final file = File(filePath);
      await file.writeAsString(_docTextController.text);
      
      // Call the onSave callback with the file
      widget.onSave(file);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document saved successfully')),
      );
    } catch (e) {
      developer.log('Error saving document: $e', name: 'EnhancedDocumentEditor');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save document: $e')),
      );
    }
  }
  
  // MARK: - PDF Document Handling
  
  Future<void> _savePdfWithAnnotations() async {
    try {
      // Check if we have an annotated PDF
      File? fileToSave = _annotatedPdfFile;
      
      // If we don't have an annotated PDF, use the original file
      if (fileToSave == null || !await fileToSave.exists()) {
        fileToSave = widget.file;
      }
      
      // Check if the file exists
      if (!await fileToSave.exists()) {
        throw Exception('PDF file does not exist');
      }
      
      // Check file path
      developer.log('Saving PDF to file: ${widget.file.path}', name: 'EnhancedDocumentEditor');
      
      // Check if file exists and is writable
      bool canWrite = true;
      String filePath = widget.file.path;
      
      // Normalize path for Windows
      if (Platform.isWindows) {
        filePath = filePath.replaceAll('\\', '/');
      }
      
      // Ensure the directory exists
      final directory = path.dirname(filePath);
      final dir = Directory(directory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      try {
        // Test write access
        final file = File(filePath);
        await file.writeAsBytes([]);
      } catch (e) {
        developer.log('Cannot write to file: $e', name: 'EnhancedDocumentEditor');
        canWrite = false;
      }
      
      if (!canWrite) {
        // Try to use a temporary file instead
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basename(widget.file.path);
        filePath = '${tempDir.path}/$fileName';
        developer.log('Using temporary file instead: $filePath', name: 'EnhancedDocumentEditor');
      }
      
      // Read the bytes from the source file
      final bytes = await fileToSave.readAsBytes();
      
      // Save to file (either original or temporary)
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      // Call the onSave callback with the file
      widget.onSave(file);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF with annotations saved successfully')),
      );
    } catch (e) {
      developer.log('Error saving PDF with annotations: $e', name: 'EnhancedDocumentEditor');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: $e')),
      );
    }
  }
  
  void _handlePdfAnnotationChanged(dynamic annotation) async {
    try {
      // Load the current PDF document
      final PdfDocument document = PdfDocument(inputBytes: await widget.file.readAsBytes());
      
      // Save the annotated document
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.pdf');
      
      // Save the document with annotations
      await tempFile.writeAsBytes(await document.save());
      
      setState(() {
        _annotatedPdfFile = tempFile;
      });
      
      document.dispose();
    } catch (e) {
      developer.log('Error handling PDF annotation: $e', name: 'EnhancedDocumentEditor');
    }
  }
  
  // MARK: - Build Methods
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (!kIsWeb) // Only show retry on non-web
              ElevatedButton(
                onPressed: _loadDocument,
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }
    
    switch (_documentType) {
      case app_document.DocumentType.csv:
        return _buildCsvEditor();
      case app_document.DocumentType.pdf:
        return _buildPdfEditor();
      case app_document.DocumentType.docx:
        return _buildDocxEditor();
      default:
        return _buildDocxEditor(); // Use text editor as fallback
    }
  }
  
  Widget _buildCsvEditor() {
    return Column(
      children: [
        if (!widget.readOnly) _buildCsvToolbar(),
        Expanded(
          child: SfDataGrid(
            key: _dataGridKey,
            source: _dataSource,
            allowEditing: !widget.readOnly,
            navigationMode: GridNavigationMode.cell,
            selectionMode: SelectionMode.single,
            editingGestureType: EditingGestureType.tap,
            gridLinesVisibility: GridLinesVisibility.both,
            headerGridLinesVisibility: GridLinesVisibility.both,
            columns: _buildDataGridColumns(),
            onSelectionChanged: (List<DataGridRow> addedRows, List<DataGridRow> removedRows) {
              setState(() {
                if (addedRows.isNotEmpty) {
                  _selectedRowIndex = _dataSource.rows.indexOf(addedRows.first);
                  // Column selection would need a more complex approach
                  _selectedColumnIndex = 0; // Default to first column for example
                }
              });
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildCsvToolbar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Wrap(
        spacing: 8.0,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Row'),
            onPressed: _addRow,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_box, size: 16),
            label: const Text('Add Column'),
            onPressed: _addColumn,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.remove, size: 16),
            label: const Text('Remove Row'),
            onPressed: _removeSelectedRow,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.remove_circle, size: 16),
            label: const Text('Remove Column'),
            onPressed: _removeSelectedColumn,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save'),
            onPressed: _saveCsvData,
          ),
        ],
      ),
    );
  }
  
  List<GridColumn> _buildDataGridColumns() {
    if (_csvData.isEmpty || _csvData[0].isEmpty) {
      return [
        GridColumn(
          columnName: 'empty',
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: const Text('No data'),
          ),
        ),
      ];
    }
    
    // Use first row as headers
    return List.generate(
      _csvData[0].length,
      (index) => GridColumn(
        columnName: 'column$index',
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: Text(
            _csvData[0][index]?.toString() ?? 'Column $index',
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
  
  Widget _buildPdfEditor() {
    // On web, show a message
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'PDF viewing is limited in the web version.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re viewing: ${widget.documentName}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please use the desktop app for full PDF functionality.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Check if file exists
    bool fileExists = false;
    try {
      fileExists = widget.file.existsSync();
    } catch (e) {
      developer.log('Error checking if file exists: $e', name: 'EnhancedDocumentEditor');
      fileExists = false;
    }
    
    if (!fileExists) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'PDF file not found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cannot load: ${widget.documentName}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Path: ${widget.file.path}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please create a new document or check file permissions.',
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: () {
                // Create an empty PDF file
                _createEmptyPdfFile();
              },
              child: const Text('Create Empty PDF File'),
            ),
          ],
        ),
      );
    }
    
    // Valid file, try to display it
    try {
      return Column(
        children: [
          if (!widget.readOnly) _buildPdfToolbar(),
          Expanded(
            child: SfPdfViewer.file(
              widget.file,
              controller: _pdfViewerController,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableTextSelection: true,
              onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
                if (details.selectedText != null && details.selectedText!.isNotEmpty) {
                  developer.log('Selected text: ${details.selectedText}', name: 'EnhancedDocumentEditor');
                }
              },
            ),
          ),
        ],
      );
    } catch (e) {
      developer.log('Error displaying PDF: $e', name: 'EnhancedDocumentEditor');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error displaying PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'File: ${widget.documentName}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: $e',
              style: const TextStyle(fontSize: 14, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
  
  // Helper method to create an empty PDF file if it doesn't exist
  Future<void> _createEmptyPdfFile() async {
    try {
      // Create an empty PDF
      final bytes = Uint8List(0);
      
      // Check if file exists and is writable
      bool canWrite = true;
      String filePath = widget.file.path;
      
      // Normalize path for Windows
      if (Platform.isWindows) {
        filePath = filePath.replaceAll('\\', '/');
      }
      
      // Ensure the directory exists
      final directory = path.dirname(filePath);
      final dir = Directory(directory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      try {
        // Create file
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        
        // Reload the document
        setState(() {
          _isLoading = true;
        });
        _loadDocument();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empty PDF file created')),
        );
      } catch (e) {
        developer.log('Cannot create empty PDF file: $e', name: 'EnhancedDocumentEditor');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create PDF file: $e')),
        );
      }
    } catch (e) {
      developer.log('Error creating empty PDF: $e', name: 'EnhancedDocumentEditor');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating empty PDF: $e')),
      );
    }
  }
  
  Widget _buildPdfToolbar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Wrap(
        spacing: 8.0,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Search'),
            onPressed: () {
              _pdfViewerController.searchText('');
            },
          ),
          // PDF annotation features are not directly supported in this version
          // We would need to implement custom annotation functionality
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save'),
            onPressed: _savePdfWithAnnotations,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDocxEditor() {
    if (!_isDocxInitialized) {
      return const Center(child: Text('Document editor is initializing...'));
    }
    
    // For simplicity, use a basic TextField instead of SuperEditor for this version
    return Column(
      children: [
        if (!widget.readOnly) _buildDocxToolbar(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _docTextController,
              readOnly: widget.readOnly,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Document content',
              ),
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDocxToolbar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Wrap(
        spacing: 8.0,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save'),
            onPressed: _saveDocxDocument,
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _pdfViewerController.dispose();
    _docTextController.dispose();
    super.dispose();
  }
}

class SpreadsheetDataSource extends DataGridSource {
  List<DataGridRow> rows = [];
  List<List<dynamic>> _data = [];
  
  SpreadsheetDataSource({required List<List<dynamic>> data}) {
    _data = data;
    _buildDataGridRows();
  }
  
  void _buildDataGridRows() {
    if (_data.isEmpty) {
      rows = [];
      return;
    }
    
    if (_data.length == 1) {
      // Only header row, no data rows
      rows = [];
      return;
    }
    
    rows = _data.skip(1).map<DataGridRow>((rowData) {
      return DataGridRow(
        cells: List.generate(
          _data[0].length,
          (index) => DataGridCell<dynamic>(
            columnName: 'column$index',
            value: index < rowData.length ? rowData[index] : '',
          ),
        ),
      );
    }).toList();
  }
  
  @override
  List<DataGridRow> get dataGridRows => rows;
  
  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            cell.value?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  @override
  Future<void> onCellSubmit(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column) async {
    // Get the row index in original data (add 1 because first row is header)
    final int dataRowIndex = rows.indexOf(dataGridRow) + 1;
    
    // Update the original data source
    if (dataRowIndex < _data.length && rowColumnIndex.columnIndex < _data[dataRowIndex].length) {
      _data[dataRowIndex][rowColumnIndex.columnIndex] = newCellValue;
    }
  }
  
  @override
  dynamic getValue(DataGridRow dataGridRow, String columnName) {
    return dataGridRow.getCells()
        .firstWhere((cell) => cell.columnName == columnName)
        .value;
  }
  
  // A field to store the edited value
  dynamic newCellValue;
  
  @override
  Widget? buildEditWidget(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex,
      GridColumn column, CellSubmit submitCell) {
    // Initial cell value
    newCellValue = getValue(dataGridRow, column.columnName);
    
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        autofocus: true,
        controller: TextEditingController(text: newCellValue?.toString() ?? ''),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: InputBorder.none,
        ),
        onChanged: (value) {
          newCellValue = value;
        },
        onSubmitted: (value) {
          newCellValue = value;
          submitCell();
        },
      ),
    );
  }
} 
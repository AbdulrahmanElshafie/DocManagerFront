import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:csv/csv.dart';
import '../models/document.dart';
import '../shared/utils/logger.dart';

class ImprovedCsvEditor extends StatefulWidget {
  final Document document;
  final Function(List<List<String>> data)? onSave;
  final String? csvContent;

  const ImprovedCsvEditor({
    super.key,
    required this.document,
    this.onSave,
    this.csvContent,
  });

  @override
  State<ImprovedCsvEditor> createState() => _ImprovedCsvEditorState();
}

class _ImprovedCsvEditorState extends State<ImprovedCsvEditor> {
  late CsvDataSource _dataSource;
  final DataGridController _dataGridController = DataGridController();
  final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();
  
  List<List<String>> _csvData = [];
  List<GridColumn> _columns = [];
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isEditing = false;
  String? _errorMessage;
  
  // Edit state
  int? _editingRowIndex;
  int? _editingColumnIndex;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCsvData();
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCsvData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (widget.csvContent != null && widget.csvContent!.isNotEmpty) {
        // Parse CSV content
        const converter = CsvToListConverter();
        final List<List<dynamic>> rawData = converter.convert(widget.csvContent!);
        
        // Convert to string data
        _csvData = rawData.map((row) => 
          row.map((cell) => cell?.toString() ?? '').toList()
        ).toList();
      } else {
        // Create default empty data
        _csvData = [
          ['Column A', 'Column B', 'Column C'],
          ['', '', ''],
          ['', '', ''],
        ];
      }

      _generateColumns();
      _dataSource = CsvDataSource(_csvData);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      LoggerUtil.error('Error loading CSV data: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _generateColumns() {
    _columns.clear();
    
    if (_csvData.isEmpty) return;
    
    // Generate columns based on the first row or number of columns
    int columnCount = _csvData.isNotEmpty ? _csvData[0].length : 3;
    
    for (int i = 0; i < columnCount; i++) {
      String columnName = 'Column ${String.fromCharCode(65 + i)}'; // A, B, C, etc.
      
      // Use first row as headers if it looks like headers
      if (_csvData.isNotEmpty && _csvData[0].length > i) {
        String firstRowValue = _csvData[0][i];
        if (firstRowValue.isNotEmpty && !_isNumeric(firstRowValue)) {
          columnName = firstRowValue;
        }
      }
      
      _columns.add(
        GridColumn(
          columnName: 'col$i',
          label: Container(
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: Text(
              columnName,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
  }

  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }

  String _getCellValue(int rowIndex, int columnIndex) {
    if (rowIndex < _csvData.length && columnIndex < _csvData[rowIndex].length) {
      return _csvData[rowIndex][columnIndex];
    }
    return '';
  }

  void _setCellValue(int rowIndex, int columnIndex, String value) {
    // Ensure the data structure is large enough
    while (rowIndex >= _csvData.length) {
      _csvData.add([]);
    }
    
    while (columnIndex >= _csvData[rowIndex].length) {
      _csvData[rowIndex].add('');
    }
    
    _csvData[rowIndex][columnIndex] = value;
    _markAsChanged();
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  void _startCellEdit(int rowIndex, int columnIndex) {
    setState(() {
      _editingRowIndex = rowIndex;
      _editingColumnIndex = columnIndex;
      _editController.text = _getCellValue(rowIndex, columnIndex);
      _isEditing = true;
    });

    // Show edit dialog
    _showEditDialog();
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Cell (${_editingRowIndex! + 1}, ${String.fromCharCode(65 + _editingColumnIndex!)})'),
        content: TextField(
          controller: _editController,
          focusNode: _editFocusNode,
          decoration: const InputDecoration(
            labelText: 'Cell Value',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 3,
          minLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelEdit();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmEdit();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      if (_isEditing) {
        _cancelEdit();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
    });
  }

  void _confirmEdit() {
    if (_editingRowIndex != null && _editingColumnIndex != null) {
      _setCellValue(_editingRowIndex!, _editingColumnIndex!, _editController.text);
      _refreshDataGrid();
    }
    _cancelEdit();
  }

  void _cancelEdit() {
    setState(() {
      _editingRowIndex = null;
      _editingColumnIndex = null;
      _isEditing = false;
    });
    _editController.clear();
  }

  void _refreshDataGrid() {
    setState(() {
      _dataSource = CsvDataSource(_csvData);
    });
  }

  void _addRow() {
    final newRow = List<String>.filled(_columns.length, '');
    _csvData.add(newRow);
    _markAsChanged();
    _refreshDataGrid();
  }

  void _addColumn() {
    // Add new column to all rows
    for (var row in _csvData) {
      row.add('');
    }
    
    // If no data, create first row
    if (_csvData.isEmpty) {
      _csvData.add(['']);
    }
    
    _generateColumns();
    _markAsChanged();
    _refreshDataGrid();
  }

  void _deleteSelectedRows() {
    final selectedRows = _dataGridController.selectedRows;
    if (selectedRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select rows to delete'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get row indices and sort in descending order to avoid index issues
    List<int> indices = selectedRows
        .map((row) => _dataSource.rows.indexOf(row))
        .where((index) => index >= 0)
        .toList()
      ..sort((a, b) => b.compareTo(a));

    for (int index in indices) {
      if (index < _csvData.length) {
        _csvData.removeAt(index);
      }
    }

    _markAsChanged();
    _refreshDataGrid();
    _dataGridController.selectedRows.clear();
  }

  Future<void> _saveChanges() async {
    if (widget.onSave != null) {
      try {
        widget.onSave!(_csvData);
        setState(() {
          _hasChanges = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Changes saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        LoggerUtil.error('Error saving CSV: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _exportCsv() {
    try {
      const converter = ListToCsvConverter();
      final csv = converter.convert(_csvData);
      
      // Here you would typically save to file or share
      // For now, we'll just show a dialog with the CSV content
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('CSV Export'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(csv),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          ElevatedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add Row'),
          ),
          ElevatedButton.icon(
            onPressed: _addColumn,
            icon: const Icon(Icons.view_column),
            label: const Text('Add Column'),
          ),
          ElevatedButton.icon(
            onPressed: _deleteSelectedRows,
            icon: const Icon(Icons.delete),
            label: const Text('Delete Selected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download),
            label: const Text('Export'),
          ),
          if (_hasChanges) ...[
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading CSV data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading CSV: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCsvData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: SfDataGrid(
              key: _dataGridKey,
              source: _dataSource,
              controller: _dataGridController,
              columns: _columns,
              allowSorting: true,
              allowMultiColumnSorting: true,
              allowColumnsResizing: true,
              columnResizeMode: ColumnResizeMode.onResize,
              selectionMode: SelectionMode.multiple,
              navigationMode: GridNavigationMode.cell,
              columnWidthMode: ColumnWidthMode.auto,
              gridLinesVisibility: GridLinesVisibility.both,
              headerGridLinesVisibility: GridLinesVisibility.both,
              rowHeight: 48,
              headerRowHeight: 56,
              onCellTap: (details) {
                // Handle cell tap for editing
                _startCellEdit(details.rowColumnIndex.rowIndex, details.rowColumnIndex.columnIndex);
              },
            ),
          ),
        ),
        if (_hasChanges)
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('You have unsaved changes'),
                const Spacer(),
                TextButton(
                  onPressed: _loadCsvData,
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveChanges,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CsvDataSource extends DataGridSource {
  List<List<String>> _csvData = [];
  List<DataGridRow> _rows = [];

  CsvDataSource(List<List<String>> csvData) {
    _csvData = csvData;
    _buildRows();
  }

  void _buildRows() {
    _rows = _csvData.asMap().entries.map((entry) {
      final rowIndex = entry.key;
      final rowData = entry.value;
      
      return DataGridRow(
        cells: rowData.asMap().entries.map((cellEntry) {
          final cellIndex = cellEntry.key;
          final cellValue = cellEntry.value;
          
          return DataGridCell<String>(
            columnName: 'col$cellIndex',
            value: cellValue,
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            cell.value.toString(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
} 
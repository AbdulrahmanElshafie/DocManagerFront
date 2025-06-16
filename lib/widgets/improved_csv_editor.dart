import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'package:csv/csv.dart';
import '../models/document.dart';
import '../shared/utils/logger.dart';
import '../shared/network/api_service.dart';
import '../shared/services/websocket_service.dart';

class ImprovedCsvEditor extends StatefulWidget {
  final Document document;
  final String? csvContent;
  final Function(List<List<String>> data)? onSave;

  const ImprovedCsvEditor({
    super.key,
    required this.document,
    this.csvContent,
    this.onSave,
  });

  @override
  State<ImprovedCsvEditor> createState() => _ImprovedCsvEditorState();
}

class _ImprovedCsvEditorState extends State<ImprovedCsvEditor> {
  late CsvDataSource _dataSource;
  final DataGridController _dataGridController = DataGridController();
  final ApiService _apiService = ApiService();
  final WebSocketService _webSocketService = WebSocketService();
  
  // Real-time editing state
  bool _isConnected = false;
  String _lastSavedCsv = '';
  DateTime? _lastSaveTime;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _saveStatusSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _documentUpdateSubscription;
  
  // CSV data state
  List<List<String>> _csvData = [];
  List<String> _columnNames = [];
  bool _isLoading = true;
  bool _hasHeader = true;
  
  // Editing state
  Timer? _saveTimer;
  
  @override
  void initState() {
    super.initState();
    _loadCsvData();
    _initializeWebSocket();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _saveStatusSubscription?.cancel();
    _errorSubscription?.cancel();
    _documentUpdateSubscription?.cancel();
    _saveTimer?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }

  void _initializeWebSocket() {
    // Connect to WebSocket for real-time editing
    _webSocketService.connectToDocument(widget.document.id);
    
    // Listen to connection state
    _connectionSubscription = _webSocketService.connectionState.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
        
        if (connected) {
          LoggerUtil.info('Real-time CSV editing connected');
        }
      }
    });
    
    // Listen to save status
    _saveStatusSubscription = _webSocketService.saveStatus.listen((status) {
      if (mounted && status.success) {
        setState(() {
          _lastSaveTime = DateTime.now();
        });
        
        if (!status.isAutoSave) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('CSV saved successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
    
    // Listen to errors
    _errorSubscription = _webSocketService.errors.listen((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(error)),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
    
    // Listen to document updates from other users
    _documentUpdateSubscription = _webSocketService.documentUpdates.listen((update) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                SizedBox(width: 8),
                Text('CSV updated by another user'),
              ],
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Refresh',
              textColor: Colors.white,
              onPressed: _loadCsvData,
            ),
          ),
        );
      }
    });
  }

  Future<void> _loadCsvData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String csvString = '';
      
      if (widget.csvContent != null) {
        csvString = widget.csvContent!;
      } else {
        // Try to get content from the document API
        try {
          final content = await _apiService.getDocumentContent(widget.document.id, 'csv');
          csvString = content['content'] ?? '';
        } catch (e) {
          // If empty or new document, create default structure
          csvString = 'Column 1,Column 2,Column 3\nRow 1 Cell 1,Row 1 Cell 2,Row 1 Cell 3\nRow 2 Cell 1,Row 2 Cell 2,Row 2 Cell 3';
        }
      }

      if (csvString.isEmpty) {
        // Create empty CSV with default structure
        csvString = 'Column 1,Column 2,Column 3\nRow 1 Cell 1,Row 1 Cell 2,Row 1 Cell 3';
      }

      // Parse CSV
      final csvTable = const CsvToListConverter().convert(csvString);
      
      if (csvTable.isNotEmpty) {
        setState(() {
          _csvData = csvTable.map((row) => row.map((cell) => cell?.toString() ?? '').toList()).toList();
          
          if (_hasHeader && _csvData.isNotEmpty) {
            _columnNames = _csvData.first.map((cell) => cell.toString()).toList();
            _csvData = _csvData.skip(1).toList();
          } else {
            _columnNames = List.generate(_csvData.isNotEmpty ? _csvData.first.length : 3, 
                (index) => 'Column ${index + 1}');
          }
        });

        _dataSource = CsvDataSource(_csvData, _onCellValueChanged);
      }
    } catch (e) {
      LoggerUtil.error('Error loading CSV: $e');
      // Create default empty CSV on error
      _createDefaultCsv();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createDefaultCsv() {
    setState(() {
      _columnNames = ['Column 1', 'Column 2', 'Column 3'];
      _csvData = [
        ['Row 1 Cell 1', 'Row 1 Cell 2', 'Row 1 Cell 3'],
        ['Row 2 Cell 1', 'Row 2 Cell 2', 'Row 2 Cell 3'],
      ];
    });

    _dataSource = CsvDataSource(_csvData, _onCellValueChanged);
  }

  void _onCellValueChanged(int rowIndex, int columnIndex, String newValue) {
    setState(() {
      if (rowIndex < _csvData.length && columnIndex < _csvData[rowIndex].length) {
        _csvData[rowIndex][columnIndex] = newValue;
      }
    });
    
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      _sendCsvUpdate();
    });
  }

  void _sendCsvUpdate() {
    // Convert CSV data to string
    final csvString = _convertToCsvString();
    
    // Only send if CSV has changed
    if (csvString != _lastSavedCsv) {
      _lastSavedCsv = csvString;
      _webSocketService.sendContentUpdate(csvString, 'csv');
    }
  }

  String _convertToCsvString() {
    final allRows = <List<String>>[];
    
    if (_hasHeader) {
      allRows.add(_columnNames);
    }
    
    allRows.addAll(_csvData.map((row) => row.map((cell) => cell.toString()).toList()));
    
    return const ListToCsvConverter().convert(allRows);
  }

  Future<void> _saveCsv() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final csvString = _convertToCsvString();
      
      await _apiService.updateDocumentContent(
        widget.document.id,
        csvString,
        'csv',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV saved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      LoggerUtil.error('Error saving CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving CSV: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addRow() {
    setState(() {
      final newRow = List.generate(_columnNames.length, (index) => '');
      _csvData.add(newRow);
      _dataSource = CsvDataSource(_csvData, _onCellValueChanged);
    });
    _scheduleAutoSave();
  }

  void _addColumn() {
    final newColumnName = 'Column ${_columnNames.length + 1}';
    
    setState(() {
      _columnNames.add(newColumnName);
      for (var row in _csvData) {
        row.add('');
      }
      _dataSource = CsvDataSource(_csvData, _onCellValueChanged);
    });
    _scheduleAutoSave();
  }

  void _removeSelectedRows() {
    final selectedRows = _dataGridController.selectedRows;
    if (selectedRows.isNotEmpty) {
      final rowsToRemove = <int>[];
      
      for (final row in selectedRows) {
        final index = _dataSource.rows.indexOf(row);
        if (index >= 0) {
          rowsToRemove.add(index);
        }
      }
      
      // Sort in descending order to remove from the end first
      rowsToRemove.sort((a, b) => b.compareTo(a));
      
      setState(() {
        for (final index in rowsToRemove) {
          if (index < _csvData.length) {
            _csvData.removeAt(index);
          }
        }
        _dataSource = CsvDataSource(_csvData, _onCellValueChanged);
      });
      
      _scheduleAutoSave();
    }
  }

  void _removeLastColumn() {
    if (_columnNames.length > 1) {
      setState(() {
        _columnNames.removeLast();
        for (var row in _csvData) {
          if (row.isNotEmpty) {
            row.removeLast();
          }
        }
        _dataSource = CsvDataSource(_csvData, _onCellValueChanged);
      });
      _scheduleAutoSave();
    }
  }

  List<GridColumn> _buildColumns() {
    return _columnNames.asMap().entries.map((entry) {
      final index = entry.key;
      final name = entry.value;
      
      return GridColumn(
        columnName: 'column$index',
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        children: [
          // Row operations
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Row'),
                onPressed: _addRow,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.remove),
                label: const Text('Remove Selected'),
                onPressed: _removeSelectedRows,
              ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Column operations
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.view_column),
                label: const Text('Add Column'),
                onPressed: _addColumn,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.remove),
                label: const Text('Remove Column'),
                onPressed: _removeLastColumn,
              ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // File operations
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: _hasHeader,
                onChanged: (value) {
                  setState(() {
                    _hasHeader = value;
                  });
                  _loadCsvData();
                },
              ),
              const Text('Has Header'),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: _isLoading ? null : _saveCsv,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _csvData.isNotEmpty
                  ? SfDataGrid(
                      source: _dataSource,
                      controller: _dataGridController,
                      columns: _buildColumns(),
                      allowEditing: true,
                      allowSorting: true,
                      allowFiltering: true,
                      selectionMode: SelectionMode.multiple,
                      navigationMode: GridNavigationMode.cell,
                      editingGestureType: EditingGestureType.tap,
                      columnResizeMode: ColumnResizeMode.onResize,
                      columnWidthMode: ColumnWidthMode.fill,
                      rowHeight: 40,
                      headerRowHeight: 45,
                      gridLinesVisibility: GridLinesVisibility.both,
                      headerGridLinesVisibility: GridLinesVisibility.both,
                    )
                  : const Center(
                      child: Text('No data available'),
                    ),
            ),
          ),
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_csvData.length} rows × ${_columnNames.length} columns'),
                Row(
                  children: [
                    if (_isConnected)
                      const Icon(Icons.cloud_done, color: Colors.green, size: 16)
                    else
                      const Icon(Icons.cloud_off, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    if (_lastSaveTime != null)
                      Text(
                        'Last saved: ${_lastSaveTime!.toString().split('.')[0]}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CsvDataSource extends DataGridSource {
  List<List<String>> _csvData;
  final Function(int rowIndex, int columnIndex, String newValue) onCellChanged;
  List<DataGridRow> _dataGridRows = [];

  CsvDataSource(this._csvData, this.onCellChanged) {
    _buildDataGridRows();
  }

  void _buildDataGridRows() {
    _dataGridRows = _csvData.asMap().entries.map<DataGridRow>((entry) {
      final row = entry.value;
      
      return DataGridRow(
        cells: row.asMap().entries.map<DataGridCell>((cellEntry) {
          final columnIndex = cellEntry.key;
          final cellValue = cellEntry.value;
          
          return DataGridCell<String>(
            columnName: 'column$columnIndex',
            value: cellValue,
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return Container(
          constraints: const BoxConstraints(minHeight: 40, maxHeight: 60),
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(
            cell.value?.toString() ?? '',
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
      constraints: const BoxConstraints(minHeight: 40, maxHeight: 60),
      padding: const EdgeInsets.all(8.0),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: TextEditingController(text: displayText),
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onSubmitted: (String value) {
          onCellChanged(rowColumnIndex.rowIndex, rowColumnIndex.columnIndex, value);
          submitCell();
        },
      ),
    );
  }

  @override
  Future<void> onCellSubmit(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column) async {
    final dynamic oldValue = dataGridRow
            .getCells()
            .firstWhere((DataGridCell dataGridCell) =>
                dataGridCell.columnName == column.columnName)
            .value ??
        '';

    final int dataRowIndex = _dataGridRows.indexOf(dataGridRow);
    if (dataRowIndex != -1) {
      final int columnIndex = int.parse(column.columnName.replaceAll('column', ''));
      if (dataRowIndex < _csvData.length && columnIndex < _csvData[dataRowIndex].length) {
        final String newValue = _csvData[dataRowIndex][columnIndex];
        
        if (oldValue != newValue) {
          _dataGridRows[dataRowIndex].getCells()[rowColumnIndex.columnIndex] =
              DataGridCell<String>(columnName: column.columnName, value: newValue);
          onCellChanged(dataRowIndex, columnIndex, newValue);
        }
      }
    }
  }
} 
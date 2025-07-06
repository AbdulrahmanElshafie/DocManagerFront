import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'dart:math';

class CsvScreen extends StatefulWidget {
  final String url;
  const CsvScreen({Key? key, required this.url}) : super(key: key);

  @override
  CsvScreenState createState() => CsvScreenState();
}

class CsvScreenState extends State<CsvScreen> {
  List<List<dynamic>> _rows = [];
  bool _loading = true, _error = false;
  String _errorMessage = '';
  
  // Dynamic sizing state
  double _defaultRowHeight = 52;
  double _headingRowHeight = 60;
  List<double> _colWidths = [];
  List<double> _rowHeights = []; // Individual row heights
  List<ColumnSize> _colSizes = [];
  bool _showControls = false;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  
  CsvDataSource? _dataSource;

  @override
  void initState() {
    super.initState();
    _fetchCsv();
  }

  Future<void> _fetchCsv() async {
    try {
      final res = await http.get(Uri.parse(widget.url));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
      }
      
      if (res.body.isEmpty) {
        throw Exception('CSV file is empty');
      }
      
      // Offload CSV parsing to background thread
      _rows = await compute(_parseCsv, res.body);
      
      if (_rows.isEmpty) {
        throw Exception('No data found in CSV file');
      }
      
      // Initialize column widths and sizes
      final headers = _rows.first.cast<String>();
      final dataRows = _rows.sublist(1);
      _colWidths = List.generate(headers.length, (index) => 150.0);
      _colSizes = List.generate(headers.length, (index) => ColumnSize.L);
      _rowHeights = List.generate(dataRows.length, (index) => _defaultRowHeight);
      
      // Create data source
      _dataSource = CsvDataSource(dataRows, headers, _colWidths, _rowHeights);
    } catch (e) {
      _error = true;
      _errorMessage = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  // Static function for background CSV parsing
  static List<List<dynamic>> _parseCsv(String csvData) {
    return const CsvToListConverter(
      eol: '\n',
      fieldDelimiter: ',',
      shouldParseNumbers: false,
    ).convert(csvData);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('CSV Viewer')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading CSV file...'),
            ],
          ),
        ),
      );
    }
    
    if (_error || _rows.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('CSV Viewer')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load CSV',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage.isNotEmpty ? _errorMessage : 'Unknown error occurred',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = false;
                    _errorMessage = '';
                  });
                  _fetchCsv();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_dataSource == null) {
      return const Scaffold(
        body: Center(child: Text('Data source not initialized')),
      );
    }

    final headers = _rows.first.cast<String>();
    final data = _rows.sublist(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV Viewer'),
        actions: [
          IconButton(
            icon: Icon(_showControls ? Icons.settings : Icons.settings_outlined),
            onPressed: () => setState(() => _showControls = !_showControls),
            tooltip: 'Table Settings',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showCsvInfo(headers.length, data.length),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Text(
              '${headers.length} columns • ${data.length} rows',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          
          // Settings Panel
          if (_showControls) _buildSettingsPanel(),
          
          // CSV Table with Draggable Borders
          Expanded(
            child: _buildDraggableTable(headers, data),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Icon(Icons.table_rows, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Text('Rows per page:', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 16),
                     DropdownButton<int>(
             value: _rowsPerPage,
             items: [5, 10, 15, 20, 25, 50, 100, 150, 200, 250, 300].map((rows) {
               return DropdownMenuItem(
                 value: rows,
                 child: Text('$rows rows'),
               );
             }).toList(),
                         onChanged: (value) {
               if (value != null) {
                 setState(() {
                   _rowsPerPage = value;
                   _currentPage = 0; // Reset to first page when changing rows per page
                   _dataSource?.notifyListeners();
                 });
               }
             },
          ),
          const SizedBox(width: 32),
          Text(
            'Drag column and row borders to resize',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableTable(List<String> headers, List<List<dynamic>> data) {
    final tableWidth = _colWidths.reduce((a, b) => a + b) + (_colWidths.length - 1) * 8;
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Header Row with Draggable Borders (Scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildHeaderRow(headers),
          ),
          
          // Virtualized Data Rows with Pagination
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: _buildVirtualizedDataRows(data),
              ),
            ),
          ),
          
          // Pagination Controls
          _buildPaginationControls(data.length),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(List<String> headers) {
    return Container(
      height: _headingRowHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < headers.length; i++) ...[
            // Header Cell
            Container(
              width: _colWidths[i],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                headers[i],
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Vertical Drag Handle (except for last column)
            if (i < headers.length - 1)
              _buildVerticalDragHandle(i),
          ],
        ],
      ),
    );
  }

  Widget _buildVirtualizedDataRows(List<List<dynamic>> data) {
    final startIndex = _currentPage * _rowsPerPage;
    final itemCount = min(_rowsPerPage, data.length - startIndex);
    
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final globalIndex = startIndex + index;
        final rowData = data[globalIndex];
        
        return Column(
          children: [
            _buildDataRow(rowData, globalIndex, index),
            // Horizontal Drag Handle (except for last row)
            if (index < itemCount - 1)
              _buildHorizontalDragHandle(globalIndex),
          ],
        );
      },
    );
  }

  Widget _buildDataRow(List<dynamic> rowData, int globalRowIndex, int displayRowIndex) {
    final rowHeight = globalRowIndex < _rowHeights.length ? _rowHeights[globalRowIndex] : _defaultRowHeight;
    
    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: displayRowIndex % 2 == 0 
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < rowData.length && i < _colWidths.length; i++) ...[
            // Data Cell
            Container(
              width: _colWidths[i],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                rowData[i].toString(),
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Vertical Drag Handle (except for last column)
            if (i < _colWidths.length - 1)
              _buildVerticalDragHandle(i),
          ],
        ],
      ),
    );
  }

  Widget _buildVerticalDragHandle(int columnIndex) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _colWidths[columnIndex] += details.delta.dx;
          _colWidths[columnIndex] = _colWidths[columnIndex].clamp(50.0, 500.0);
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 8,
          height: double.infinity,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              height: double.infinity,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalDragHandle(int globalRowIndex) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          if (globalRowIndex < _rowHeights.length) {
            _rowHeights[globalRowIndex] += details.delta.dy;
            _rowHeights[globalRowIndex] = _rowHeights[globalRowIndex].clamp(30.0, 200.0);
          }
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: Container(
          height: 8,
          width: _colWidths.reduce((a, b) => a + b) + (_colWidths.length - 1) * 8, // Account for drag handles
          color: Colors.transparent,
          child: Center(
            child: Container(
              height: 2,
              width: double.infinity,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

     int _getTotalPages(int dataLength) => (dataLength / _rowsPerPage).ceil().clamp(1, double.infinity).toInt();

  Widget _buildPaginationControls(int totalRows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${_currentPage * _rowsPerPage + 1}-${((_currentPage + 1) * _rowsPerPage).clamp(0, totalRows)} of $totalRows rows',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                icon: const Icon(Icons.first_page),
                tooltip: 'First page',
              ),
              IconButton(
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                                 child: Text('${_currentPage + 1} / ${_getTotalPages(totalRows)}'),
              ),
              IconButton(
                                 onPressed: _currentPage < _getTotalPages(totalRows) - 1 ? () => setState(() => _currentPage++) : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page',
              ),
              IconButton(
                                 onPressed: _currentPage < _getTotalPages(totalRows) - 1 ? () => setState(() => _currentPage = _getTotalPages(totalRows) - 1) : null,
                icon: const Icon(Icons.last_page),
                tooltip: 'Last page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCsvInfo(int columnCount, int rowCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Columns: $columnCount'),
            Text('Rows: $rowCount'),
            Text('Total cells: ${columnCount * rowCount}'),
            const SizedBox(height: 16),
            const Text(
              'Features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('• Drag column borders to resize columns'),
            const Text('• Drag row borders to resize individual row heights'),
            const Text('• Customizable pagination (5-300 rows per page)'),
            const Text('• Horizontal and vertical scrolling'),
            const Text('• Virtualized rendering for optimal performance'),
            const SizedBox(height: 8),
            const Text(
              'Use the settings panel to adjust rows per page. Performance optimized with virtualization for large datasets.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
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
}

// Data source for custom pagination
class CsvDataSource extends DataTableSource {
  final List<List<dynamic>> _data;
  final List<String> _headers;
  final List<double> _colWidths;
  final List<double> _rowHeights;

  CsvDataSource(this._data, this._headers, this._colWidths, this._rowHeights);

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    
    final row = _data[index];
    return DataRow(
      cells: row.asMap().entries.map((entry) {
        final cellIndex = entry.key;
        final cellValue = entry.value;
        
        return DataCell(
          ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: _colWidths[cellIndex]),
            child: Container(
              alignment: Alignment.centerLeft,
              child: Text(
                cellValue.toString(),
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _data.length;

  @override
  int get selectedRowCount => 0;
} 
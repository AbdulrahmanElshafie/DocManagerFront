import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/document.dart';
import '../shared/utils/logger.dart';
import '../shared/network/api_service.dart';
import 'dart:developer' as developer;

class ImprovedPdfViewer extends StatefulWidget {
  final Document document;
  final Uint8List? pdfBytes;
  final String? pdfUrl;
  final Function(String content, String contentType)? onSave;

  const ImprovedPdfViewer({
    super.key,
    required this.document,
    this.pdfBytes,
    this.pdfUrl,
    this.onSave,
  });

  @override
  State<ImprovedPdfViewer> createState() => _ImprovedPdfViewerState();
}

class _ImprovedPdfViewerState extends State<ImprovedPdfViewer> {
  late PdfViewerController _pdfController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  final ApiService _apiService = ApiService();
  
  // Save state
  bool _isConnected = true; // Always connected for HTTP API
  String _lastSaveTime = '';
  bool _isSaving = false;
  
  // Annotation and interaction state
  PdfInteractionMode _interactionMode = PdfInteractionMode.selection;
  bool _isAnnotationMode = false;
  bool _isNoteMode = false;
  bool _isDrawingMode = false;
  Color _selectedAnnotationColor = Colors.yellow;
  double _strokeWidth = 2.0;
  List<PdfAnnotation> _annotations = [];
  List<PdfNote> _notes = [];
  
  // Drawing annotations
  List<Map<String, dynamic>> _drawingAnnotations = [];
  
  // Search state
  PdfTextSearchResult? _searchResult;
  bool _isSearching = false;
  String _searchText = '';
  int _currentSearchIndex = 0;
  
  // UI state
  bool _canShowScrollHead = false;
  int _currentPageNumber = 1;
  int _totalPageCount = 0;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _loadAnnotations();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }



  void _showSnackBar(String message, Color color, IconData icon) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadAnnotations() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
      
      // Use correct API endpoint format
      final response = await _apiService.get(
        '/manager/document/${widget.document.id}/annotations/',
        {}
      );
      
      developer.log('Annotations response: $response', name: 'PdfViewer');
      
      // Handle annotations data properly
      if (response.isNotEmpty) {
        // Parse drawing annotations
        if (response['drawings'] != null) {
          final drawingsData = response['drawings'] as List;
          setState(() {
            _drawingAnnotations = drawingsData.cast<Map<String, dynamic>>();
          });
        }
        
        // Parse text annotations
        if (response['annotations'] != null) {
          final annotationsData = response['annotations'] as List;
          final loadedAnnotations = <PdfAnnotation>[];
          
          for (final data in annotationsData) {
            try {
              loadedAnnotations.add(PdfAnnotation.fromJson(data as Map<String, dynamic>));
            } catch (e) {
              developer.log('Error parsing annotation: $e', name: 'PdfViewer');
            }
          }
          
          setState(() {
            _annotations = loadedAnnotations;
          });
        }
        
        // Parse notes
        if (response['notes'] != null) {
          final notesData = response['notes'] as List;
          final loadedNotes = <PdfNote>[];
          
          for (final data in notesData) {
            try {
              loadedNotes.add(PdfNote.fromJson(data as Map<String, dynamic>));
            } catch (e) {
              developer.log('Error parsing note: $e', name: 'PdfViewer');
            }
          }
          
          setState(() {
            _notes = loadedNotes;
          });
        }
      }
      
      developer.log('Loaded ${_drawingAnnotations.length} drawings, ${_annotations.length} annotations and ${_notes.length} notes', name: 'PdfViewer');
      
    } catch (e) {
      LoggerUtil.error('Failed to load annotations: $e');
      
      // Don't show error for initial load - annotations might not exist yet for new documents
      // Only set error state if it's not a 404 (file not found) error
      if (!e.toString().contains('404')) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load annotations: $e';
        });
      }
      
      developer.log('Annotations load error (may be normal for new documents): $e', name: 'PdfViewer');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAnnotations() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final annotationsJson = _annotations.map((a) => a.toJson()).toList();
      final notesJson = _notes.map((n) => n.toJson()).toList();
      
      developer.log('Saving ${_drawingAnnotations.length} drawings, ${annotationsJson.length} annotations and ${notesJson.length} notes', name: 'PdfViewer');
      
      await _apiService.put(
        '/manager/document/${widget.document.id}/annotations/',
        {
          'drawings': _drawingAnnotations,
          'annotations': annotationsJson,
          'notes': notesJson,
        },
        ''
      );

      _showSnackBar('Annotations saved successfully', Colors.green, Icons.check_circle);
      
    } catch (e) {
      LoggerUtil.error('Failed to save annotations: $e');
      _showSnackBar('Failed to save annotations: $e', Colors.red, Icons.error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPageNumber = details.newPageNumber;
    });
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _totalPageCount = details.document.pages.count;
    });
  }

  void _onTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    if (details.selectedText == null || details.selectedText!.isEmpty) {
      return;
    }
    
    if (_isAnnotationMode) {
      _addTextAnnotation(details);
    }
  }

  void _addTextAnnotation(PdfTextSelectionChangedDetails details) {
    final annotation = PdfAnnotation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: details.selectedText ?? '',
      bounds: details.globalSelectedRegion ?? Rect.zero,
      pageNumber: _currentPageNumber,
      color: _selectedAnnotationColor,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _annotations.add(annotation);
    });
    
    _saveAnnotations();
    
    // Show feedback
    _showSnackBar('Text annotation added', Colors.blue, Icons.highlight);
  }

  void _addNote(double x, double y) {
    showDialog(
      context: context,
      builder: (context) {
        String noteText = '';
        return AlertDialog(
          title: const Text('Add Note'),
          content: TextField(
            onChanged: (value) => noteText = value,
            decoration: const InputDecoration(
              hintText: 'Enter your note...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (noteText.trim().isNotEmpty) {
                  final note = PdfNote(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    text: noteText.trim(),
                    x: x,
                    y: y,
                    pageNumber: _currentPageNumber,
                    color: _selectedAnnotationColor,
                    timestamp: DateTime.now(),
                  );
                  
                  setState(() {
                    _notes.add(note);
                  });
                  
                  _saveAnnotations();
                  Navigator.pop(context);
                  
                  _showSnackBar('Note added', Colors.blue, Icons.note_add);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeAnnotation(String id) {
    setState(() {
      _annotations.removeWhere((annotation) => annotation.id == id);
    });
    _saveAnnotations();
    _showSnackBar('Annotation removed', Colors.orange, Icons.delete);
  }

  void _removeNote(String id) {
    setState(() {
      _notes.removeWhere((note) => note.id == id);
    });
    _saveAnnotations();
    _showSnackBar('Note removed', Colors.orange, Icons.delete);
  }

  void _startSearch() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search PDF'),
          content: TextField(
            onChanged: (value) => _searchText = value,
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
                if (_searchText.trim().isNotEmpty) {
                  _performSearch();
                  Navigator.pop(context);
                }
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  void _performSearch() {
    setState(() {
      _isSearching = true;
      _currentSearchIndex = 0;
    });
    
    _searchResult = _pdfController.searchText(_searchText);
    
    if (_searchResult != null) {
      _searchResult!.addListener(() {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      });
    }
  }

  void _searchNext() {
    if (_searchResult != null) {
      _searchResult!.nextInstance();
    }
  }

  void _searchPrevious() {
    if (_searchResult != null) {
      _searchResult!.previousInstance();
    }
  }

  void _clearSearch() {
    if (_searchResult != null) {
      _searchResult!.clear();
      setState(() {
        _searchResult = null;
        _isSearching = false;
        _searchText = '';
      });
    }
  }

  void _clearAllAnnotations() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Annotations'),
        content: const Text('Are you sure you want to remove all annotations, drawings, and notes? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _drawingAnnotations.clear();
                _annotations.clear();
                _notes.clear();
              });
              _saveAnnotations();
              Navigator.pop(context);
              _showSnackBar('All annotations cleared', Colors.orange, Icons.clear);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Zoom controls
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
            
            const SizedBox(width: 16),
            
            // Annotation tools
            IconButton(
              onPressed: () => setState(() {
                _isAnnotationMode = !_isAnnotationMode;
                _isNoteMode = false;
                _isDrawingMode = false;
                if (_isAnnotationMode) {
                  _interactionMode = PdfInteractionMode.selection;
                }
              }),
              icon: const Icon(Icons.highlight),
              tooltip: 'Highlight Text',
              color: _isAnnotationMode ? Theme.of(context).primaryColor : null,
            ),
            IconButton(
              onPressed: () => setState(() {
                _isDrawingMode = !_isDrawingMode;
                _isAnnotationMode = false;
                _isNoteMode = false;
                if (_isDrawingMode) {
                  _interactionMode = PdfInteractionMode.pan;
                } else {
                  _interactionMode = PdfInteractionMode.selection;
                }
              }),
              icon: const Icon(Icons.draw),
              tooltip: 'Draw on PDF',
              color: _isDrawingMode ? Theme.of(context).primaryColor : null,
            ),
            IconButton(
              onPressed: () => setState(() {
                _isNoteMode = !_isNoteMode;
                _isAnnotationMode = false;
                _isDrawingMode = false;
              }),
              icon: const Icon(Icons.note_add),
              tooltip: 'Add Note',
              color: _isNoteMode ? Theme.of(context).primaryColor : null,
            ),
            
            // Color picker
            PopupMenuButton<Color>(
              icon: Icon(
                Icons.color_lens,
                color: _selectedAnnotationColor,
              ),
              tooltip: 'Select Color',
              onSelected: (color) => setState(() {
                _selectedAnnotationColor = color;
              }),
              itemBuilder: (context) => [
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.red,
                Colors.orange,
                Colors.purple,
              ].map((color) => PopupMenuItem<Color>(
                value: color,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Color'),
                  ],
                ),
              )).toList(),
            ),
            
            // Stroke width picker
            if (_isDrawingMode)
              PopupMenuButton<double>(
                icon: const Icon(Icons.line_weight),
                tooltip: 'Stroke Width',
                onSelected: (width) => setState(() {
                  _strokeWidth = width;
                }),
                itemBuilder: (context) => [
                  1.0, 2.0, 3.0, 4.0, 5.0, 6.0
                ].map((width) => PopupMenuItem<double>(
                  value: width,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: width * 2,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(width),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${width.toInt()}px'),
                    ],
                  ),
                )).toList(),
              ),
            
            const SizedBox(width: 16),
            
            // Search controls
            IconButton(
              onPressed: _startSearch,
              icon: const Icon(Icons.search),
              tooltip: 'Search PDF',
            ),
            
            if (_searchResult != null) ...[
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
              IconButton(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close),
                tooltip: 'Clear Search',
              ),
            ],
            
            const SizedBox(width: 16),
            
            // Save button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveAnnotations,
              icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
              label: const Text('Save'),
            ),
            
            const SizedBox(width: 8),
            
            // Clear annotations button
            if (_drawingAnnotations.isNotEmpty || _annotations.isNotEmpty || _notes.isNotEmpty)
              TextButton.icon(
                onPressed: _clearAllAnnotations,
                icon: const Icon(Icons.clear_all, color: Colors.red),
                label: const Text('Clear All', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    // Check if we have PDF data
    if (widget.pdfBytes == null || widget.pdfBytes!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No PDF data available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTapDown: (details) {
        if (_isNoteMode) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final localPosition = renderBox.globalToLocal(details.globalPosition);
            _addNote(localPosition.dx, localPosition.dy);
          }
        }
      },
      child: SfPdfViewer.memory(
        widget.pdfBytes!,
        key: _pdfViewerKey,
        controller: _pdfController,
        canShowScrollHead: _canShowScrollHead,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        enableDoubleTapZooming: true,
        enableTextSelection: !_isDrawingMode,
        onPageChanged: _onPageChanged,
        onDocumentLoaded: _onDocumentLoaded,
        onTextSelectionChanged: _onTextSelectionChanged,
        interactionMode: _interactionMode,
      ),
    );
  }

  Widget _buildNotesOverlay() {
    final currentPageNotes = _notes.where((note) => note.pageNumber == _currentPageNumber).toList();
    
    if (currentPageNotes.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      ignoring: !_isNoteMode,
      child: Stack(
        children: currentPageNotes.map((note) => Positioned(
          left: note.x.clamp(0.0, MediaQuery.of(context).size.width - 50),
          top: note.y.clamp(50.0, MediaQuery.of(context).size.height - 100),
          child: GestureDetector(
            onTap: () => _showNoteDetails(note),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: note.color.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.note,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  void _showNoteDetails(PdfNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.note, color: note.color),
            const SizedBox(width: 8),
            Expanded(child: Text('Note - Page ${note.pageNumber}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                note.text,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Added: ${note.timestamp.toString().split('.')[0]}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _removeNote(note.id);
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Page $_currentPageNumber of $_totalPageCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_drawingAnnotations.isNotEmpty || _annotations.isNotEmpty || _notes.isNotEmpty) ...[
                const SizedBox(width: 16),
                Text(
                  '${_drawingAnnotations.length} drawings, ${_annotations.length} annotations, ${_notes.length} notes',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          Row(
                          children: [
                Icon(
                  Icons.wifi,
                  size: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  'Connected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (_lastSaveTime.isNotEmpty) ...[
                const SizedBox(width: 16),
                Text(
                  'Last saved: ${_lastSaveTime.split('T')[1].split('.')[0]}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading PDF',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _hasError = false;
                _errorMessage = '';
              });
              _loadAnnotations();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.document.name),
          backgroundColor: Colors.red.shade50,
        ),
        body: _buildErrorWidget(),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _buildTopToolbar(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildPdfViewer()),
                if (_notes.isNotEmpty) 
                  Positioned.fill(child: _buildNotesOverlay()),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }
}

// Data models for annotations and notes
class PdfAnnotation {
  final String id;
  final String text;
  final Rect bounds;
  final int pageNumber;
  final Color color;
  final DateTime timestamp;

  PdfAnnotation({
    required this.id,
    required this.text,
    required this.bounds,
    required this.pageNumber,
    required this.color,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'bounds': {
        'left': bounds.left,
        'top': bounds.top,
        'right': bounds.right,
        'bottom': bounds.bottom,
      },
      'pageNumber': pageNumber,
      'color': color.value,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PdfAnnotation.fromJson(Map<String, dynamic> json) {
    return PdfAnnotation(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      bounds: json['bounds'] != null ? Rect.fromLTRB(
        (json['bounds']['left'] ?? 0.0).toDouble(),
        (json['bounds']['top'] ?? 0.0).toDouble(),
        (json['bounds']['right'] ?? 0.0).toDouble(),
        (json['bounds']['bottom'] ?? 0.0).toDouble(),
      ) : Rect.zero,
      pageNumber: json['pageNumber'] ?? 1,
      color: Color(json['color'] ?? Colors.yellow.value),
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'])
        : DateTime.now(),
    );
  }
}

class PdfNote {
  final String id;
  final String text;
  final double x;
  final double y;
  final int pageNumber;
  final Color color;
  final DateTime timestamp;

  PdfNote({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.pageNumber,
    required this.color,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'x': x,
      'y': y,
      'pageNumber': pageNumber,
      'color': color.value,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PdfNote.fromJson(Map<String, dynamic> json) {
    return PdfNote(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      pageNumber: json['pageNumber'] ?? 1,
      color: Color(json['color'] ?? Colors.yellow.value),
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'])
        : DateTime.now(),
    );
  }
} 
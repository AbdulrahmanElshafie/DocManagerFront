import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/document.dart';
import '../shared/utils/logger.dart';

class ImprovedPdfViewer extends StatefulWidget {
  final Document document;
  final Uint8List? pdfBytes;
  final String? pdfUrl;

  const ImprovedPdfViewer({
    super.key,
    required this.document,
    this.pdfBytes,
    this.pdfUrl,
  });

  @override
  State<ImprovedPdfViewer> createState() => _ImprovedPdfViewerState();
}

class _ImprovedPdfViewerState extends State<ImprovedPdfViewer> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  late PdfViewerController _pdfController;
  
  // Search functionality
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  PdfTextSearchResult? _searchResult;
  int _currentSearchResultIndex = 0;
  bool _isSearching = false;
  
  // UI state
  bool _showAppBar = true;
  int _currentPageNumber = 1;
  int _totalPageCount = 0;
  double _zoomLevel = 1.0;
  
  // Text selection and highlighting
  bool _canShowScrollHead = false;
  PdfTextSelectionChangedDetails? _textSelectionDetails;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pdfController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    } else {
      _clearSearch();
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
    });

    try {
      _searchResult = await _pdfController.searchText(query);
      if (_searchResult != null && _searchResult!.totalInstanceCount > 0) {
        setState(() {
          _currentSearchResultIndex = 1;
          _isSearching = false;
        });
        // Highlight the first result
        _searchResult!.nextInstance();
      } else {
        setState(() {
          _isSearching = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No results found for "$query"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      LoggerUtil.error('Error performing search: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    _searchResult?.clear();
    setState(() {
      _searchResult = null;
      _currentSearchResultIndex = 0;
      _isSearching = false;
    });
  }

  void _nextSearchResult() {
    if (_searchResult != null && _searchResult!.hasResult) {
      if (_currentSearchResultIndex < _searchResult!.totalInstanceCount) {
        setState(() {
          _currentSearchResultIndex++;
        });
        _searchResult!.nextInstance();
      }
    }
  }

  void _previousSearchResult() {
    if (_searchResult != null && _searchResult!.hasResult) {
      if (_currentSearchResultIndex > 1) {
        setState(() {
          _currentSearchResultIndex--;
        });
        _searchResult!.previousInstance();
      }
    }
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (_showSearchBar) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      } else {
        _clearSearch();
        _searchController.clear();
      }
    });
  }

  void _zoomIn() {
    _pdfController.zoomLevel = (_pdfController.zoomLevel + 0.25).clamp(0.5, 3.0);
  }

  void _zoomOut() {
    _pdfController.zoomLevel = (_pdfController.zoomLevel - 0.25).clamp(0.5, 3.0);
  }

  void _resetZoom() {
    _pdfController.zoomLevel = 1.0;
  }

  void _goToPage(int pageNumber) {
    _pdfController.jumpToPage(pageNumber);
  }

  void _showPageJumpDialog() {
    final TextEditingController pageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: pageController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Page number (1-$_totalPageCount)',
            border: const OutlineInputBorder(),
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
              final pageNumber = int.tryParse(pageController.text);
              if (pageNumber != null && pageNumber >= 1 && pageNumber <= _totalPageCount) {
                _goToPage(pageNumber);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid page number'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    ).then((_) => pageController.dispose());
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search in document...',
                prefixIcon: _isSearching 
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _clearSearch();
                      },
                    )
                  : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (value) => _performSearch(value),
            ),
          ),
          if (_searchResult != null && _searchResult!.hasResult) ...[
            const SizedBox(width: 8),
            Text(
              '$_currentSearchResultIndex of ${_searchResult!.totalInstanceCount}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: _previousSearchResult,
              tooltip: 'Previous result',
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: _nextSearchResult,
              tooltip: 'Next result',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _toggleSearchBar,
            tooltip: 'Close search',
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Row(
        children: [
          // Page navigation
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentPageNumber > 1 ? () => _goToPage(1) : null,
            tooltip: 'First page',
          ),
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: _currentPageNumber > 1 
              ? () => _pdfController.previousPage() 
              : null,
            tooltip: 'Previous page',
          ),
          
          // Page indicator
          GestureDetector(
            onTap: _showPageJumpDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                '$_currentPageNumber / $_totalPageCount',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: _currentPageNumber < _totalPageCount 
              ? () => _pdfController.nextPage() 
              : null,
            tooltip: 'Next page',
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: _currentPageNumber < _totalPageCount 
              ? () => _goToPage(_totalPageCount) 
              : null,
            tooltip: 'Last page',
          ),
          
          const VerticalDivider(),
          
          // Zoom controls
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
            tooltip: 'Zoom out',
          ),
          Text(
            '${(_zoomLevel * 100).round()}%',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
            tooltip: 'Zoom in',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _resetZoom,
            tooltip: 'Reset zoom',
          ),
          
          const Spacer(),
          
          // Search button
          IconButton(
            icon: Icon(_showSearchBar ? Icons.search_off : Icons.search),
            onPressed: _toggleSearchBar,
            tooltip: _showSearchBar ? 'Hide search' : 'Search',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _showAppBar ? AppBar(
        title: Text(widget.document.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () {
              setState(() {
                _showAppBar = false;
              });
            },
            tooltip: 'Fullscreen',
          ),
        ],
      ) : null,
      body: Column(
        children: [
          if (!_showAppBar)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fullscreen_exit),
                        onPressed: () {
                          setState(() {
                            _showAppBar = true;
                          });
                        },
                        tooltip: 'Exit fullscreen',
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.document.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_showSearchBar) _buildSearchBar(),
          _buildToolbar(),
          Expanded(
            child: _buildPdfViewer(),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    if (widget.pdfBytes != null) {
      return SfPdfViewer.memory(
        widget.pdfBytes!,
        key: _pdfViewerKey,
        controller: _pdfController,
        enableTextSelection: true,
        enableHyperlinkNavigation: true,
        canShowScrollHead: _canShowScrollHead,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          setState(() {
            _totalPageCount = details.document.pages.count;
          });
        },
        onPageChanged: (PdfPageChangedDetails details) {
          setState(() {
            _currentPageNumber = details.newPageNumber;
          });
        },
        onZoomLevelChanged: (PdfZoomDetails details) {
          setState(() {
            _zoomLevel = details.newZoomLevel;
          });
        },
        onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
          setState(() {
            _textSelectionDetails = details;
            _canShowScrollHead = details.selectedText?.isNotEmpty ?? false;
          });
        },
      );
    } else if (widget.pdfUrl != null) {
      return SfPdfViewer.network(
        widget.pdfUrl!,
        key: _pdfViewerKey,
        controller: _pdfController,
        enableTextSelection: true,
        enableHyperlinkNavigation: true,
        canShowScrollHead: _canShowScrollHead,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          setState(() {
            _totalPageCount = details.document.pages.count;
          });
        },
        onPageChanged: (PdfPageChangedDetails details) {
          setState(() {
            _currentPageNumber = details.newPageNumber;
          });
        },
        onZoomLevelChanged: (PdfZoomDetails details) {
          setState(() {
            _zoomLevel = details.newZoomLevel;
          });
        },
        onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
          setState(() {
            _textSelectionDetails = details;
            _canShowScrollHead = details.selectedText?.isNotEmpty ?? false;
          });
        },
      );
    } else {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('No PDF data available'),
          ],
        ),
      );
    }
  }
} 
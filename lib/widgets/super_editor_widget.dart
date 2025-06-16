import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;
import 'dart:async';
import '../models/document.dart' as doc_model;
import '../shared/network/api_service.dart';
import '../shared/services/websocket_service.dart';
import '../shared/utils/logger.dart';

class SuperEditorWidget extends StatefulWidget {
  final doc_model.Document document;
  final String? initialContent;
  final String contentFormat;
  final Function(String content, String contentType)? onSave;

  const SuperEditorWidget({
    super.key,
    required this.document,
    this.initialContent,
    this.contentFormat = 'html',
    this.onSave,
  });

  @override
  State<SuperEditorWidget> createState() => _SuperEditorWidgetState();
}

class _SuperEditorWidgetState extends State<SuperEditorWidget> {
  late MutableDocument _document;
  late MutableDocumentComposer _composer;
  late Editor _editor;
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _isDocumentFileCreated = false;
  
  // WebSocket integration
  WebSocketService? _websocketService;
  StreamSubscription? _websocketSubscription;
  
  // Auto-save functionality
  Timer? _saveTimer;
  String _lastSavedContent = '';

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  @override
  void dispose() {
    _websocketSubscription?.cancel();
    _websocketService?.disconnect();
    _saveTimer?.cancel();
    super.dispose();
  }

  void _initializeEditor() {
    // Create document with empty content initially
    _document = MutableDocument(
      nodes: [
        ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(''),
        )
      ],
    );
    
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _document, 
      composer: _composer,
    );
    
    // Listen for document changes
    _document.addListener((changeLog) => _onDocumentChanged());
    
    _loadDocumentContent();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    try {
      _websocketService = WebSocketService();
      _websocketService!.connectToDocument(widget.document.id);
      
      _websocketSubscription = _websocketService!.saveStatus.listen((status) {
        setState(() {
          _isSaving = false;
          if (status.success) {
            _hasUnsavedChanges = false;
          }
        });
        if (status.success) {
          LoggerUtil.info('Document auto-saved successfully');
          if (!status.isAutoSave) {
            _showSuccessMessage('Document saved successfully');
          }
        } else {
          LoggerUtil.error('Auto-save failed');
          _showErrorMessage('Auto-save failed');
        }
      });
    } catch (e) {
      LoggerUtil.error('Failed to setup WebSocket: $e');
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(message),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadDocumentContent() async {
    try {
      setState(() => _isLoading = true);
      
      String content = widget.initialContent ?? '';
      
      // Check if document has an associated file
      _isDocumentFileCreated = widget.document.file != null && widget.document.file!.path.isNotEmpty;
      
      if (content.isEmpty && _isDocumentFileCreated) {
        // Load content from backend
        final apiService = ApiService();
        try {
          final response = await apiService.getDocumentContent(widget.document.id, 'html');
          content = response['content'] ?? '';
        } catch (e) {
          LoggerUtil.error('Failed to load document content: $e');
          // If document has no file yet, start with default content
          if (e.toString().contains('No file associated')) {
            _isDocumentFileCreated = false;
            content = '';
          } else {
            content = '<p>Error loading document content</p>';
          }
        }
      }

      if (content.isEmpty) {
        content = '<p>Start writing your document...</p>';
      }

      _lastSavedContent = content;
      _parseContentToDocument(content);
      
      setState(() => _isLoading = false);
    } catch (e) {
      LoggerUtil.error('Error loading document content: $e');
      setState(() => _isLoading = false);
    }
  }

  void _parseContentToDocument(String content) {
    try {
      List<DocumentNode> nodes = [];
      
      if (widget.contentFormat == 'html') {
        nodes = _parseHtmlContent(content);
      } else if (widget.contentFormat == 'markdown') {
        nodes = _parseMarkdownContent(content);
      } else {
        // Plain text
        nodes = [
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(content),
          )
        ];
      }

      if (nodes.isEmpty) {
        nodes = [
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(''),
          )
        ];
      }

      // Clear existing content and add new nodes
      while (_document.nodeCount > 0) {
        _document.deleteNodeAt(0);
      }
      
      for (final node in nodes) {
        _document.add(node);
      }
      
    } catch (e) {
      LoggerUtil.error('Error parsing content: $e');
      // Clear document and add error message
      while (_document.nodeCount > 0) {
        _document.deleteNodeAt(0);
      }
      _document.add(ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText('Error parsing document content'),
      ));
    }
  }

  List<DocumentNode> _parseHtmlContent(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final body = document.body;
    
    if (body == null) {
      return [ParagraphNode(id: Editor.createNodeId(), text: AttributedText(''))];
    }

    List<DocumentNode> nodes = [];
    
    for (final element in body.children) {
      switch (element.localName?.toLowerCase()) {
        case 'h1':
          nodes.add(ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(element.text),
            metadata: {'blockType': header1Attribution},
          ));
          break;
        case 'h2':
          nodes.add(ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(element.text),
            metadata: {'blockType': header2Attribution},
          ));
          break;
        case 'h3':
          nodes.add(ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(element.text),
            metadata: {'blockType': header3Attribution},
          ));
          break;
        case 'ul':
          for (final li in element.children.where((e) => e.localName == 'li')) {
            nodes.add(ListItemNode.unordered(
              id: Editor.createNodeId(),
              text: AttributedText(li.text),
            ));
          }
          break;
        case 'ol':
          for (final li in element.children.where((e) => e.localName == 'li')) {
            nodes.add(ListItemNode.ordered(
              id: Editor.createNodeId(),
              text: AttributedText(li.text),
            ));
          }
          break;
        case 'p':
        default:
          final text = element.text.trim();
          if (text.isNotEmpty) {
            nodes.add(ParagraphNode(
              id: Editor.createNodeId(),
              text: AttributedText(text),
            ));
          }
          break;
      }
    }

    return nodes.isEmpty ? [ParagraphNode(id: Editor.createNodeId(), text: AttributedText(''))] : nodes;
  }

  List<DocumentNode> _parseMarkdownContent(String markdownContent) {
    final htmlContent = md.markdownToHtml(markdownContent);
    return _parseHtmlContent(htmlContent);
  }

  void _onDocumentChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
    
    if (_saveTimer?.isActive == true) {
      _saveTimer!.cancel();
    }
    
    _saveTimer = Timer(const Duration(seconds: 3), () {
      _autoSaveDocument();
    });
  }

  Future<void> _autoSaveDocument() async {
    if (_isSaving) return;

    try {
      final currentContent = _documentToHtml();
      if (currentContent == _lastSavedContent) return;

      setState(() => _isSaving = true);
      
      // If document file is not created yet, create it first
      if (!_isDocumentFileCreated) {
        await _createDocumentFile(currentContent);
        return; // _createDocumentFile will handle the saving
      }
      
      if (_websocketService != null) {
        _websocketService!.sendContentUpdate(currentContent, widget.contentFormat);
      } else {
        // Fallback to direct API call
        final apiService = ApiService();
        await apiService.updateDocumentContent(
          widget.document.id,
          currentContent,
          widget.contentFormat,
        );
        setState(() {
          _isSaving = false;
          _hasUnsavedChanges = false;
        });
      }
      
      _lastSavedContent = currentContent;
      
    } catch (e) {
      LoggerUtil.error('Auto-save failed: $e');
      setState(() => _isSaving = false);
      
      // If it's a "no file associated" error, try to create the file
      if (e.toString().contains('No file associated')) {
        final currentContent = _documentToHtml();
        await _createDocumentFile(currentContent);
      }
    }
  }

  Future<void> _createDocumentFile(String content) async {
    try {
      setState(() => _isSaving = true);
      
      final apiService = ApiService();
      
      // Update document with document_type to trigger file creation
      await apiService.put('/manager/document/', {
        'name': widget.document.name,
        'folder': widget.document.folderId,
        'document_type': 'docx', // Specify DOCX type for backend to create empty file
      }, widget.document.id);
      
      // Wait a moment for file creation
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Now update the content
      await apiService.updateDocumentContent(
        widget.document.id,
        content,
        'html',
      );
      
      setState(() {
        _isDocumentFileCreated = true;
        _isSaving = false;
        _hasUnsavedChanges = false;
      });
      
      _lastSavedContent = content;
      _showSuccessMessage('Document file created and saved');
      
    } catch (e) {
      LoggerUtil.error('Failed to create document file: $e');
      setState(() => _isSaving = false);
      _showErrorMessage('Failed to create document file: $e');
    }
  }

  String _documentToHtml() {
    try {
      final buffer = StringBuffer();
      
      for (int i = 0; i < _document.nodeCount; i++) {
        final node = _document.getNodeAt(i);
        if (node is ParagraphNode) {
          final blockType = node.getMetadataValue('blockType');
          final text = node.text.toPlainText();
          
          if (blockType == header1Attribution) {
            buffer.writeln('<h1>$text</h1>');
          } else if (blockType == header2Attribution) {
            buffer.writeln('<h2>$text</h2>');
          } else if (blockType == header3Attribution) {
            buffer.writeln('<h3>$text</h3>');
          } else {
            buffer.writeln('<p>$text</p>');
          }
        } else if (node is ListItemNode) {
          final text = node.text.toPlainText();
          if (node.type == ListItemType.unordered) {
            buffer.writeln('<ul><li>$text</li></ul>');
          } else {
            buffer.writeln('<ol><li>$text</li></ol>');
          }
        }
      }
      
      return buffer.toString();
    } catch (e) {
      LoggerUtil.error('Error converting document to HTML: $e');
      return '<p>Error converting document</p>';
    }
  }

  Future<void> _manualSave() async {
    try {
      setState(() => _isSaving = true);
      
      final content = _documentToHtml();
      
      // If document file is not created yet, create it first
      if (!_isDocumentFileCreated) {
        await _createDocumentFile(content);
        return;
      }
      
      if (_websocketService != null) {
        _websocketService!.forceSave();
      } else {
        final apiService = ApiService();
        await apiService.updateDocumentContent(
          widget.document.id,
          content,
          widget.contentFormat,
        );
      }
      
      if (widget.onSave != null) {
        widget.onSave!(content, widget.contentFormat);
      }
      
      _lastSavedContent = content;
      
      _showSuccessMessage('Document saved successfully');
      
      setState(() {
        _hasUnsavedChanges = false;
      });
      
    } catch (e) {
      LoggerUtil.error('Manual save failed: $e');
      _showErrorMessage('Save failed: $e');
    } finally {
      setState(() => _isSaving = false);
    }
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
            Text('Loading document...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Toolbar
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
              // Bold (simplified for compatibility)
              IconButton(
                onPressed: () {
                  LoggerUtil.info('Bold formatting requested');
                  // TODO: Implement when super_editor API is stable
                },
                icon: const Icon(Icons.format_bold),
                tooltip: 'Bold',
              ),
              // Italic (simplified for compatibility)
              IconButton(
                onPressed: () {
                  LoggerUtil.info('Italic formatting requested');
                  // TODO: Implement when super_editor API is stable
                },
                icon: const Icon(Icons.format_italic),
                tooltip: 'Italic',
              ),
              // Underline (simplified for compatibility)
              IconButton(
                onPressed: () {
                  LoggerUtil.info('Underline formatting requested');
                  // TODO: Implement when super_editor API is stable
                },
                icon: const Icon(Icons.format_underlined),
                tooltip: 'Underline',
              ),
              const VerticalDivider(),
              // Header (simplified for compatibility)
              IconButton(
                onPressed: () {
                  LoggerUtil.info('Header formatting requested');
                  // TODO: Implement when super_editor API is stable
                },
                icon: const Icon(Icons.title),
                tooltip: 'Header',
              ),
              // Bullet List (simplified for compatibility)
              IconButton(
                onPressed: () {
                  LoggerUtil.info('Bullet list requested');
                  // TODO: Implement when super_editor API is stable
                },
                icon: const Icon(Icons.format_list_bulleted),
                tooltip: 'Bullet List',
              ),
              // Numbered List (simplified for compatibility)
              IconButton(
                onPressed: () {
                  LoggerUtil.info('Numbered list requested');
                  // TODO: Implement when super_editor API is stable
                },
                icon: const Icon(Icons.format_list_numbered),
                tooltip: 'Numbered List',
              ),
              const Spacer(),
              // Connection status
              if (_websocketService != null)
                StreamBuilder<bool>(
                  stream: _websocketService!.connectionState,
                  builder: (context, snapshot) {
                    final isConnected = snapshot.data ?? false;
                    return Row(
                      children: [
                        Icon(
                          isConnected ? Icons.cloud_done : Icons.cloud_off,
                          color: isConnected ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConnected ? 'Connected' : 'Offline',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(width: 16),
              // Unsaved changes indicator
              if (_hasUnsavedChanges)
                const Row(
                  children: [
                    Icon(Icons.edit, size: 16, color: Colors.orange),
                    SizedBox(width: 4),
                    Text('Unsaved', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    SizedBox(width: 8),
                  ],
                ),
              // Save button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _manualSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
        // Status bar
        if (!_isDocumentFileCreated)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange.shade100,
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Document file will be created when you start typing and save.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        // Editor
        Expanded(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SuperEditor(
              editor: _editor,
              composer: _composer,
              componentBuilders: defaultComponentBuilders,
              stylesheet: Stylesheet(
                rules: [
                  StyleRule(
                    BlockSelector.all,
                    (doc, docNode) {
                      return {
                        Styles.textStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        Styles.padding: const CascadingPadding.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                      };
                    },
                  ),
                  StyleRule(
                    const BlockSelector("header1"),
                    (doc, docNode) {
                      return {
                        Styles.textStyle: TextStyle(
                          color: Theme.of(context).textTheme.headlineLarge?.color ?? Colors.black,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        Styles.padding: const CascadingPadding.only(
                          left: 16,
                          right: 16,
                          top: 24,
                          bottom: 8,
                        ),
                      };
                    },
                  ),
                  StyleRule(
                    const BlockSelector("header2"),
                    (doc, docNode) {
                      return {
                        Styles.textStyle: TextStyle(
                          color: Theme.of(context).textTheme.headlineMedium?.color ?? Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        Styles.padding: const CascadingPadding.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 8,
                        ),
                      };
                    },
                  ),
                  StyleRule(
                    const BlockSelector("header3"),
                    (doc, docNode) {
                      return {
                        Styles.textStyle: TextStyle(
                          color: Theme.of(context).textTheme.headlineSmall?.color ?? Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                        Styles.padding: const CascadingPadding.only(
                          left: 16,
                          right: 16,
                          top: 12,
                          bottom: 8,
                        ),
                      };
                    },
                  ),
                  StyleRule(
                    const BlockSelector("paragraph"),
                    (doc, docNode) {
                      return {
                        Styles.textStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        Styles.padding: const CascadingPadding.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      };
                    },
                  ),
                  StyleRule(
                    const BlockSelector("listItem"),
                    (doc, docNode) {
                      return {
                        Styles.textStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        Styles.padding: const CascadingPadding.only(
                          left: 40,
                          right: 16,
                          top: 4,
                          bottom: 4,
                        ),
                      };
                    },
                  ),
                ],
                inlineTextStyler: (attributions, existingStyle) {
                  return existingStyle.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
} 
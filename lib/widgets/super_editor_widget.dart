import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as md;
import '../models/document.dart' as doc_model;
import '../shared/utils/logger.dart';

class SuperEditorWidget extends StatefulWidget {
  final doc_model.Document document;
  final String? initialContent;
  final String contentFormat; // 'html' or 'markdown'
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
  bool _hasChanges = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  void _initializeEditor() {
    try {
      // Create empty document
      _document = MutableDocument(
        nodes: [
          ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('Start typing...'),
          ),
        ],
      );
      _composer = MutableDocumentComposer();
      
      // Create editor
      _editor = createDefaultDocumentEditor(
        document: _document,
        composer: _composer,
      );

      // Load initial content if provided
      if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
        _loadContent(widget.initialContent!, widget.contentFormat);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      LoggerUtil.error('Error initializing Super Editor: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadContent(String content, String format) {
    try {
      // Clear existing content
      if (_document.nodeCount > 0) {
        final firstNode = _document.getNodeAt(0)!;
        _document.deleteNode(firstNode.id);
      }
      
      if (format == 'html') {
        _loadHtmlContent(content);
      } else if (format == 'markdown') {
        _loadMarkdownContent(content);
      } else {
        // Plain text
        _loadPlainTextContent(content);
      }
      
    } catch (e) {
      LoggerUtil.error('Error loading content: $e');
      // Fallback to plain text
      _loadPlainTextContent(content);
    }
  }

  void _loadHtmlContent(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final body = document.body;
    
    if (body == null) {
      _loadPlainTextContent(htmlContent);
      return;
    }

    // Simple HTML parsing - just extract text and basic formatting
    final text = body.text.trim();
    if (text.isNotEmpty) {
      _document.insertNodeAt(0, ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(text),
      ));
    } else {
      _document.insertNodeAt(0, ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(''),
      ));
    }
  }

  void _loadMarkdownContent(String markdownContent) {
    // Convert markdown to HTML first, then parse
    final htmlContent = md.markdownToHtml(markdownContent);
    _loadHtmlContent(htmlContent);
  }

  void _loadPlainTextContent(String textContent) {
    final lines = textContent.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      _document.insertNodeAt(i, ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(lines[i]),
      ));
    }

    // If no content, add empty paragraph
    if (lines.isEmpty || (lines.length == 1 && lines[0].isEmpty)) {
      _document.insertNodeAt(0, ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(''),
      ));
    }
  }

  String _exportToHtml() {
    final buffer = StringBuffer();
    buffer.writeln('<html><body>');
    
    for (int i = 0; i < _document.nodeCount; i++) {
      final node = _document.getNodeAt(i);
      if (node is TextNode) {
        final text = node.text.toPlainText();
        
        if (node is ParagraphNode) {
          buffer.writeln('<p>$text</p>');
        } else if (node is ListItemNode) {
          if (node.type == ListItemType.ordered) {
            buffer.writeln('<ol><li>$text</li></ol>');
          } else {
            buffer.writeln('<ul><li>$text</li></ul>');
          }
        } else {
          buffer.writeln('<p>$text</p>');
        }
      }
    }
    
    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  String _exportToMarkdown() {
    final buffer = StringBuffer();
    
    for (int i = 0; i < _document.nodeCount; i++) {
      final node = _document.getNodeAt(i);
      if (node is TextNode) {
        final text = node.text.toPlainText();
        
        if (node is ParagraphNode) {
          buffer.writeln(text);
        } else if (node is ListItemNode) {
          if (node.type == ListItemType.ordered) {
            buffer.writeln('1. $text');
          } else {
            buffer.writeln('- $text');
          }
        } else {
          buffer.writeln(text);
        }
        buffer.writeln(); // Add blank line between paragraphs
      }
    }
    
    return buffer.toString().trim();
  }

  void _saveContent() {
    if (widget.onSave != null) {
      try {
        String content;
        String contentType;
        
        if (widget.contentFormat == 'markdown') {
          content = _exportToMarkdown();
          contentType = 'markdown';
        } else {
          content = _exportToHtml();
          contentType = 'html';
        }
        
        widget.onSave!(content, contentType);
        
        setState(() {
          _hasChanges = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        LoggerUtil.error('Error saving document: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
                _initializeEditor();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.format_bold),
                onPressed: () {
                  // TODO: Implement bold formatting
                },
              ),
              IconButton(
                icon: const Icon(Icons.format_italic),
                onPressed: () {
                  // TODO: Implement italic formatting
                },
              ),
              IconButton(
                icon: const Icon(Icons.format_underlined),
                onPressed: () {
                  // TODO: Implement underline formatting
                },
              ),
              const Spacer(),
              if (_hasChanges)
                ElevatedButton(
                  onPressed: _saveContent,
                  child: const Text('Save'),
                ),
            ],
          ),
        ),
        // Editor
        Expanded(
          child: SuperEditor(
            editor: _editor,
            stylesheet: defaultStylesheet.copyWith(
              documentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
} 
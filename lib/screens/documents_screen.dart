import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/document/document_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/blocs/document/document_state.dart';
import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/shared/components/responsive_builder.dart';
import 'package:doc_manager/screens/document_detail_screen.dart';

class DocumentsScreen extends StatefulWidget {
  final String? folderId;
  
  const DocumentsScreen({super.key, this.folderId});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late DocumentBloc _documentBloc;
  final _searchController = TextEditingController();
  final _documentNameController = TextEditingController();
  String? _searchQuery;
  DocumentType _selectedDocumentType = DocumentType.pdf;
  
  @override
  void initState() {
    super.initState();
    _documentBloc = context.read<DocumentBloc>();
    _loadDocuments();
  }
  
  void _loadDocuments() {
    _documentBloc.add(LoadDocuments(folderId: widget.folderId, query: _searchQuery));
  }
  
  void _createDocument() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _documentNameController,
              decoration: const InputDecoration(
                labelText: 'Document Name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DocumentType>(
              decoration: const InputDecoration(
                labelText: 'Document Type',
              ),
              value: DocumentType.pdf,
              items: DocumentType.values.map((type) {
                return DropdownMenuItem<DocumentType>(
                  value: type,
                  child: Text(type.toString().split('.').last.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDocumentType = value ?? DocumentType.pdf;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _documentNameController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_documentNameController.text.isNotEmpty) {
                // Create an empty document with the selected type
                final newDocument = Document.empty(
                  name: _documentNameController.text,
                  type: _selectedDocumentType,
                  folderId: widget.folderId ?? '',
                );
                
                // Close dialog and navigate to document detail screen
                Navigator.pop(context);
                
                // Open the document directly in edit mode
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => DocumentDetailScreen(
                      document: newDocument,
                      isEditing: true,
                      isNewDocument: true,
                    ),
                  ),
                ).then((_) {
                  // Reload documents when returning from the detail screen
                  _loadDocuments();
                });
                
                _documentNameController.clear();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderId == null ? 'All Documents' : 'Folder Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: BlocConsumer<DocumentBloc, DocumentState>(
        listener: (context, state) {
          if (state is DocumentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error)),
            );
          } else if (state is DocumentOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is DocumentsLoading || state is DocumentLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DocumentsLoaded) {
            final documents = state.documents;
            if (documents.isEmpty) {
              return const Center(
                child: Text('No documents found. Create a new one!'),
              );
            }
            
            return ResponsiveBuilder(
              mobile: _buildMobileLayout(documents),
              tablet: _buildTabletLayout(documents),
              desktop: _buildDesktopLayout(documents),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createDocument,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildMobileLayout(List<Document> documents) {
    return ListView.builder(
      itemCount: documents.length,
      itemBuilder: (context, index) {
        return _buildDocumentListItem(documents[index]);
      },
    );
  }
  
  Widget _buildTabletLayout(List<Document> documents) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        return _buildDocumentCard(documents[index]);
      },
    );
  }
  
  Widget _buildDesktopLayout(List<Document> documents) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.5,
      ),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        return _buildDocumentCard(documents[index]);
      },
    );
  }
  
  Widget _buildDocumentCard(Document document) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => DocumentDetailScreen(document: document),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.blue.shade100,
              height: 80,
              width: double.infinity,
              child: Center(
                child: Icon(
                  Icons.description,
                  size: 48,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last modified: ${document.updatedAt?.toString().split('.')[0] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => DocumentDetailScreen(document: document, isEditing: true),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () {
                      _deleteDocument(document);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDocumentListItem(Document document) {
    return ListTile(
      leading: const Icon(Icons.description),
      title: Text(document.name),
      subtitle: Text('Last modified: ${document.updatedAt?.toString().split('.')[0] ?? 'N/A'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => DocumentDetailScreen(document: document, isEditing: true),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _deleteDocument(document);
            },
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) => DocumentDetailScreen(document: document),
          ),
        );
      },
    );
  }
  
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Documents'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Enter search query',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.isEmpty ? null : value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _loadDocuments();
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
  
  void _deleteDocument(Document document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${document.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _documentBloc.add(DeleteDocument(document.id, folderId: widget.folderId));
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _documentNameController.dispose();
    super.dispose();
  }
} 
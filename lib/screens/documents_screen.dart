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
    final List<String> availableTemplates = [];
    String? selectedTemplate;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                value: _selectedDocumentType,
                items: DocumentType.values.map((type) {
                  return DropdownMenuItem<DocumentType>(
                    value: type,
                    child: Text(type.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDocumentType = value ?? DocumentType.pdf;
                    
                    // Update available templates based on selected type
                    switch (_selectedDocumentType) {
                      case DocumentType.pdf:
                        availableTemplates.clear();
                        availableTemplates.addAll(['Blank', 'Business Letter', 'Invoice', 'Report', 'Certificate']);
                        break;
                      case DocumentType.docx:
                        availableTemplates.clear();
                        availableTemplates.addAll(['Blank', 'Letter', 'Resume', 'Meeting Minutes', 'Project Proposal']);
                        break;
                      case DocumentType.csv:
                        availableTemplates.clear();
                        availableTemplates.addAll(['Blank', 'Contacts', 'Inventory', 'Financial', 'Project Planning']);
                        break;
                      default:
                        availableTemplates.clear();
                        availableTemplates.add('Blank');
                    }
                    
                    // Reset selected template
                    selectedTemplate = availableTemplates.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (availableTemplates.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Template',
                  ),
                  value: selectedTemplate ?? availableTemplates.first,
                  items: availableTemplates.map((template) {
                    return DropdownMenuItem<String>(
                      value: template,
                      child: Text(template),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedTemplate = value;
                    });
                  },
                ),
              const SizedBox(height: 16),
              // Add a template description
              if (selectedTemplate != null && selectedTemplate != 'Blank')
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getTemplateDescription(selectedTemplate!, _selectedDocumentType),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
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
                  // Check if the file name has the correct extension for the selected type
                  String fileName = _documentNameController.text;
                  switch (_selectedDocumentType) {
                    case DocumentType.pdf:
                      if (!fileName.toLowerCase().endsWith('.pdf')) {
                        fileName = '$fileName.pdf';
                      }
                      break;
                    case DocumentType.docx:
                      if (!fileName.toLowerCase().endsWith('.docx')) {
                        fileName = '$fileName.docx';
                      }
                      break;
                    case DocumentType.csv:
                      if (!fileName.toLowerCase().endsWith('.csv')) {
                        fileName = '$fileName.csv';
                      }
                      break;
                  }
                  
                  // Create an empty document with the selected type
                  final newDocument = Document.empty(
                    name: fileName,
                    type: _selectedDocumentType,
                    folderId: widget.folderId ?? '',
                  );
                  
                  // Apply template if one was selected
                  final template = selectedTemplate ?? 'Blank';
                  
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
                        initialTemplate: template != 'Blank' ? template : null,
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
      ),
    );
  }
  
  // Get description for template
  String _getTemplateDescription(String templateName, DocumentType documentType) {
    switch (documentType) {
      case DocumentType.pdf:
        switch (templateName) {
          case 'Business Letter':
            return 'A professional letter template with company header, date, and signature sections.';
          case 'Invoice':
            return 'A standard invoice with itemized listing, pricing, and total calculations.';
          case 'Report':
            return 'A formal report structure with introduction, findings, and conclusion sections.';
          case 'Certificate':
            return 'An achievement certificate with decorative border and signature fields.';
          default:
            return 'A blank PDF document.';
        }
      case DocumentType.docx:
        switch (templateName) {
          case 'Letter':
            return 'A standard letter template with sender and recipient information.';
          case 'Resume':
            return 'A professional resume/CV template with sections for experience, skills, and education.';
          case 'Meeting Minutes':
            return 'A template for recording meeting proceedings with attendees, discussion points, and action items.';
          case 'Project Proposal':
            return 'A comprehensive project proposal template with sections for objectives, timeline, and budget.';
          default:
            return 'A blank Word document.';
        }
      case DocumentType.csv:
        switch (templateName) {
          case 'Contacts':
            return 'A contact list with columns for name, email, phone, address, and company.';
          case 'Inventory':
            return 'An inventory tracker with item details, quantities, and supplier information.';
          case 'Financial':
            return 'A financial tracker with income, expenses, and balance calculations.';
          case 'Project Planning':
            return 'A project task list with assignments, due dates, and status tracking.';
          default:
            return 'A blank spreadsheet.';
        }
      default:
        return 'A blank document.';
    }
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
    // Get the appropriate icon based on document type
    IconData iconData;
    Color iconColor;
    
    switch (document.type) {
      case DocumentType.pdf:
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red.shade700;
        break;
      case DocumentType.docx:
        iconData = Icons.description;
        iconColor = Colors.blue.shade700;
        break;
      case DocumentType.csv:
        iconData = Icons.table_chart;
        iconColor = Colors.green.shade700;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey.shade700;
    }
    
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
              color: Colors.blue.shade50,
              height: 80,
              width: double.infinity,
              child: Center(
                child: Icon(
                  iconData,
                  size: 48,
                  color: iconColor,
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
                    maxLines: 1,
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
                  const SizedBox(height: 4),
                  Text(
                    'Type: ${document.type.toString().split('.').last.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: iconColor,
                      fontWeight: FontWeight.bold,
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
    // Get the appropriate icon based on document type
    IconData iconData;
    Color iconColor;
    
    switch (document.type) {
      case DocumentType.pdf:
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red.shade700;
        break;
      case DocumentType.docx:
        iconData = Icons.description;
        iconColor = Colors.blue.shade700;
        break;
      case DocumentType.csv:
        iconData = Icons.table_chart;
        iconColor = Colors.green.shade700;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey.shade700;
    }
    
    return ListTile(
      leading: Icon(iconData, color: iconColor, size: 32),
      title: Text(document.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last modified: ${document.updatedAt?.toString().split('.')[0] ?? 'N/A'}'),
          Text(
            'Type: ${document.type.toString().split('.').last.toUpperCase()}', 
            style: TextStyle(color: iconColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      isThreeLine: true,
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
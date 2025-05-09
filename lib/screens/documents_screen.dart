import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/blocs/document/document_bloc.dart';
import 'package:doc_manager/blocs/document/document_event.dart';
import 'package:doc_manager/blocs/document/document_state.dart';
import 'package:doc_manager/models/document.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
      ),
      body: BlocProvider(
        create: (context) => DocumentBloc(
          documentRepository: context.read(),
        )..add(const LoadDocuments()),
        child: BlocConsumer<DocumentBloc, DocumentState>(
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
            if (state is DocumentsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is DocumentsLoaded) {
              return _buildDocumentsList(context, state.documents);
            } else {
              return const Center(child: Text('Load documents to get started'));
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add document screen
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDocumentsList(BuildContext context, List<Document> documents) {
    if (documents.isEmpty) {
      return const Center(child: Text('No documents found'));
    }
    
    return ListView.builder(
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        return ListTile(
          title: Text(document.name),
          subtitle: Text('Created: ${document.createdAt.toString().split('.')[0]}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // Navigate to edit document screen
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  _showDeleteConfirmationDialog(context, document);
                },
              ),
            ],
          ),
          onTap: () {
            context.read<DocumentBloc>().add(LoadDocument(document.id));
          },
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context, Document document) async {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Document'),
          content: Text('Are you sure you want to delete "${document.name}"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<DocumentBloc>().add(DeleteDocument(document.id));
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
} 
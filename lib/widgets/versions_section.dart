import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/models/version.dart';
import 'package:doc_manager/blocs/version/version_bloc.dart';
import 'package:doc_manager/blocs/version/version_event.dart';
import 'package:doc_manager/blocs/version/version_state.dart';

class VersionsSection extends StatefulWidget {
  final String documentId;
  
  const VersionsSection({super.key, required this.documentId});

  @override
  State<VersionsSection> createState() => _VersionsSectionState();
}

class _VersionsSectionState extends State<VersionsSection> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersionBloc, VersionState>(
      builder: (context, state) {
        if (state is VersionLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is VersionError) {
          return Center(child: Text('Error: ${state.error}'));
        } else if (state is VersionsLoaded) {
          return _buildVersionsList(state.versions);
        }
        
        return _buildVersionsList([]);
      },
    );
  }
  
  Widget _buildVersionsList(List<Version> versions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Versions (${versions.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Version'),
              onPressed: () {
                context.read<VersionBloc>().add(
                  CreateVersion(
                    documentId: widget.documentId,
                    versionId: '',
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Versions list
        if (versions.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No versions available',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: versions.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final version = versions[index];
              return ListTile(
                title: Text('Version ${index + 1}'),
                subtitle: Text(
                  'Created: ${version.createdAt.toString().split('.')[0]}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore),
                      tooltip: 'Restore this version',
                      onPressed: () {
                        context.read<VersionBloc>().add(
                          LoadVersions(
                            widget.documentId,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      tooltip: 'View this version',
                      onPressed: () {
                        // Show version content in a dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Version ${index + 1}'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Created: ${version.createdAt.toString().split('.')[0]}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (version.content != null && version.content!.isNotEmpty)
                                      Text(version.content!)
                                    else
                                      const Text('No content available for this version'),
                                  ],
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.read<VersionBloc>().add(
                                    LoadVersions(
                                      widget.documentId,
                                    ),
                                  );
                                },
                                child: const Text('Restore This Version'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
} 
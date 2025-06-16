import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/models/activity_log.dart';
import 'package:doc_manager/blocs/activity_log/activity_log_bloc.dart';
import 'package:doc_manager/blocs/activity_log/activity_log_event.dart';
import 'package:doc_manager/blocs/activity_log/activity_log_state.dart';
import 'package:doc_manager/shared/network/api_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

class MetadataSection extends StatefulWidget {
  final Document document;
  
  const MetadataSection({super.key, required this.document});

  @override
  State<MetadataSection> createState() => _MetadataSectionState();
}

class _MetadataSectionState extends State<MetadataSection> {
  late ActivityLogBloc _activityLogBloc;
  final ApiService _apiService = ApiService();
  String? _documentContent;
  bool _isLoadingContent = false;
  
  // Resizable section heights
  double _previewSectionHeight = 200;
  double _metadataSectionHeight = 300;
  double _statsSectionHeight = 250;
  double _activitySectionHeight = 400;
  
  final double _minSectionHeight = 150;
  final double _maxSectionHeight = 600;

  @override
  void initState() {
    super.initState();
    _activityLogBloc = context.read<ActivityLogBloc>();
    _loadActivityData();
    _loadDocumentPreview();
  }

  @override
  void didUpdateWidget(MetadataSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when document changes
    if (oldWidget.document.id != widget.document.id) {
      _loadActivityData();
      _loadDocumentPreview();
    }
  }

  void _loadActivityData() {
    // Load both activity logs and stats simultaneously
    _activityLogBloc.add(LoadDocumentActivityData(
      documentId: widget.document.id,
      limit: 5,
    ));
  }

  Future<void> _loadDocumentPreview() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingContent = true;
    });

    try {
      // Try to get document content for preview
      final response = await _apiService.get('/manager/document/${widget.document.id}/content/', {
        'format': 'html'
      });
      
      if (mounted) {
        setState(() {
          _documentContent = response['content']?.toString() ?? 'No content available';
          _isLoadingContent = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _documentContent = 'Unable to load document preview';
          _isLoadingContent = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          // Document Preview Card - Resizable
          _buildResizableSection(
            title: 'Document Preview',
            height: _previewSectionHeight,
            content: _buildDocumentPreviewContent(),
            onResize: (delta) {
              setState(() {
                _previewSectionHeight = (_previewSectionHeight + delta)
                    .clamp(_minSectionHeight, _maxSectionHeight);
              });
            },
          ),
          
          // Document Metadata Card - Resizable
          _buildResizableSection(
            title: 'Document Metadata',
            height: _metadataSectionHeight,
            content: _buildMetadataContent(),
            onResize: (delta) {
              setState(() {
                _metadataSectionHeight = (_metadataSectionHeight + delta)
                    .clamp(_minSectionHeight, _maxSectionHeight);
              });
            },
          ),
          
          // Activity Statistics Card - Resizable
          _buildResizableSection(
            title: 'Activity Statistics',
            height: _statsSectionHeight,
            content: _buildActivityStatsContent(),
            onResize: (delta) {
              setState(() {
                _statsSectionHeight = (_statsSectionHeight + delta)
                    .clamp(_minSectionHeight, _maxSectionHeight);
              });
            },
          ),
          
          // Recent Activity Card - Resizable
          _buildResizableSection(
            title: 'Recent Activity',
            height: _activitySectionHeight,
            content: _buildRecentActivityContent(),
            onResize: (delta) {
              setState(() {
                _activitySectionHeight = (_activitySectionHeight + delta)
                    .clamp(_minSectionHeight, _maxSectionHeight);
              });
            },
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildResizableSection({
    required String title,
    required double height,
    required Widget content,
    required Function(double) onResize,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: height,
            child: Column(
              children: [
                // Header with title
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.drag_indicator,
                        color: Colors.grey.shade400,
                        size: 16,
                      ),
                    ],
                  ),
                ),
                
                // Content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Resize handle (only show if not last section)
        if (!isLast)
          GestureDetector(
            onPanUpdate: (details) {
              onResize(details.delta.dy);
            },
            child: Container(
              height: 20,
              width: double.infinity,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(
                    Icons.drag_handle,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentPreviewContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Document icon
        Container(
          width: 120,
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: _getDocumentColor(widget.document.type).withOpacity(0.1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getDocumentIcon(widget.document.type),
                size: 48,
                color: _getDocumentColor(widget.document.type),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  widget.document.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getDocumentTypeString(widget.document.type),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        
        // Document content preview
        Expanded(
          child: Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: _isLoadingContent
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Text(
                      _getPreviewText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document info rows
          _buildInfoRow('Name', widget.document.name),
          _buildInfoRow('Type', _getDocumentTypeString(widget.document.type)),
          _buildInfoRow('Created', _formatDate(widget.document.createdAt)),
          _buildInfoRow('Last Modified', widget.document.updatedAt != null ? _formatDate(widget.document.updatedAt!) : 'N/A'),
          _buildInfoRow('Document ID', widget.document.id),
          _buildInfoRow('Owner ID', widget.document.ownerId),
          if (widget.document.folderId != null)
            _buildInfoRow('Folder ID', widget.document.folderId!),
          
          // Show file path if available
          if (widget.document.filePath != null && widget.document.filePath!.isNotEmpty)
            _buildInfoRow('Path', _formatFilePath(widget.document.filePath!)),
            
          // Add file access status for local files
          if (widget.document.filePath != null && widget.document.filePath!.isNotEmpty && 
              !widget.document.filePath!.startsWith('http://') && 
              !widget.document.filePath!.startsWith('https://') &&
              !kIsWeb)
            _buildInfoRow(
              'Status', 
              File(widget.document.filePath!).existsSync() ? 'Accessible' : 'Not Found'
            ),
        ],
      ),
    );
  }

  Widget _buildActivityStatsContent() {
    return BlocBuilder<ActivityLogBloc, ActivityLogState>(
      builder: (context, state) {
        if (state is ActivityStatsLoading || state is ActivityLogsLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        } 
        
        Map<String, dynamic>? stats;
        if (state is ActivityStatsLoaded) {
          stats = state.stats;
        } else if (state is ActivityDataLoaded) {
          stats = state.stats;
        }
        
        if (stats != null) {
          final totalActivities = stats['total_activities'] ?? 0;
          
          if (totalActivities == 0) {
            return Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No activity data',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Statistics will appear as you use this document',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildStatRow('Total Activities', totalActivities.toString()),
                _buildStatRow('Recent (24h)', stats['recent_activities_24h']?.toString() ?? '0'),
                if (stats['activity_counts'] != null) ...[
                  const SizedBox(height: 8),
                  const Text('Activity Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...((stats['activity_counts'] as Map<String, dynamic>).entries
                      .where((e) => (e.value as int) > 0)
                      .take(5)
                      .map((e) => _buildStatRow(
                          _formatActivityType(e.key), 
                          e.value.toString()
                      ))),
                ],
              ],
            ),
          );
        } else if (state is ActivityLogError) {
          return Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'Error loading stats',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.error,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade500,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _activityLogBloc.add(LoadDocumentActivityData(
                    documentId: widget.document.id,
                    limit: 5,
                  )),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'Loading statistics...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentActivityContent() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
                            IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _activityLogBloc.add(LoadDocumentActivityData(
                    documentId: widget.document.id,
                    limit: 5,
                  )),
                ),
          ],
        ),
        const SizedBox(height: 8),
        
                  Expanded(
            child: BlocBuilder<ActivityLogBloc, ActivityLogState>(
            builder: (context, state) {
              if (state is ActivityLogsLoading || state is ActivityStatsLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              } 
              
              List<ActivityLog>? activities;
              if (state is ActivityLogsLoaded) {
                activities = state.activityLogs;
              } else if (state is ActivityDataLoaded) {
                activities = state.activityLogs;
              }
              
              if (activities != null) {
                if (activities.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No recent activity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Activity will appear here when you interact with this document',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (context, index) => _buildActivityItem(activities[index]),
                );
              } else if (state is ActivityLogError) {
                return Container(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading activities',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.error,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _activityLogBloc.add(LoadDocumentActivityData(
                          documentId: widget.document.id,
                          limit: 5,
                        )),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loading activities...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(ActivityLog activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            _getActivityIcon(activity.activityType),
            size: 20,
            color: _getActivityColor(activity.activityType),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activityTypeDisplay,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (activity.description != null)
                  Text(
                    activity.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            _formatRelativeTime(activity.timestamp),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getPreviewText() {
    if (_documentContent == null) {
      return 'Loading preview...';
    }
    
    // Strip HTML tags for preview
    String preview = _documentContent!
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    if (preview.isEmpty) {
      return 'No content available for preview';
    }
    
    return preview.length > 300 ? '${preview.substring(0, 300)}...' : preview;
  }

  // Helper methods for UI
  IconData _getDocumentIcon(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.csv:
        return Icons.table_chart;
      case DocumentType.docx:
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentColor(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Colors.red;
      case DocumentType.csv:
        return Colors.green;
      case DocumentType.docx:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getDocumentTypeString(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return 'PDF Document';
      case DocumentType.csv:
        return 'CSV Spreadsheet';
      case DocumentType.docx:
        return 'Word Document';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatFilePath(String filePath) {
    // Truncate long file paths for display
    if (filePath.length > 50) {
      return '...${filePath.substring(filePath.length - 47)}';
    }
    return filePath;
  }

  String _formatActivityType(String activityType) {
    return activityType.split('_').map((word) => 
        word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  IconData _getActivityIcon(String activityType) {
    switch (activityType) {
      case 'view':
        return Icons.visibility;
      case 'edit':
        return Icons.edit;
      case 'create':
        return Icons.add_circle;
      case 'delete':
        return Icons.delete;
      case 'download':
        return Icons.download;
      case 'upload':
        return Icons.upload;
      case 'share':
        return Icons.share;
      default:
        return Icons.history;
    }
  }

  Color _getActivityColor(String activityType) {
    switch (activityType) {
      case 'view':
        return Colors.blue;
      case 'edit':
        return Colors.orange;
      case 'create':
        return Colors.green;
      case 'delete':
        return Colors.red;
      case 'download':
        return Colors.purple;
      case 'upload':
        return Colors.indigo;
      case 'share':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
} 
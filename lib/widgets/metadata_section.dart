import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:doc_manager/models/document.dart';
import 'package:doc_manager/models/activity_log.dart';
import 'package:doc_manager/blocs/activity_log/activity_log_bloc.dart';
import 'package:doc_manager/blocs/activity_log/activity_log_event.dart';
import 'package:doc_manager/blocs/activity_log/activity_log_state.dart';

import 'dart:io' if (dart.library.html) 'dart:html';
import 'dart:io' as io show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../shared/utils/file_utils.dart';

// Platform-specific File class handling
typedef PlatformFile = File;

class MetadataSection extends StatefulWidget {
  final Document document;
  
  const MetadataSection({super.key, required this.document});

  @override
  State<MetadataSection> createState() => _MetadataSectionState();
}

class _MetadataSectionState extends State<MetadataSection> {
  late ActivityLogBloc _activityLogBloc;
  String? _documentFilePath;
  bool _isLoadingPreview = false;
  
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
    _prepareDocumentPreview();
  }

  @override
  void didUpdateWidget(MetadataSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when document changes
    if (oldWidget.document.id != widget.document.id) {
      _loadActivityData();
      _prepareDocumentPreview();
    }
  }

  void _loadActivityData() {
    // Load both activity logs and stats simultaneously
    _activityLogBloc.add(LoadDocumentActivityData(
      documentId: widget.document.id,
      limit: 5,
    ));
  }

  String _makeFullUrl(String relativePath) {
    // Convert relative API path to full URL
    final baseUrl = 'http://172.22.253.81:8000';
    if (relativePath.startsWith('/')) {
      return '$baseUrl$relativePath';
    } else {
      return '$baseUrl/$relativePath';
    }
  }

  bool _isUrl(String? path) {
    if (path == null) return false;
    return path.startsWith('http://') || path.startsWith('https://');
  }

  bool _isRelativeApiPath(String? path) {
    if (path == null) return false;
    return path.startsWith('/media/') || path.startsWith('media/');
  }

  Future<void> _prepareDocumentPreview() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingPreview = true;
    });

    try {
      final filePath = widget.document.filePath ?? FileUtils.getFilePath(widget.document.file);
      
      if (_isUrl(filePath)) {
        // Remote file - download to temp directory
        await _downloadAndSaveRemoteFile(filePath!);
      } else if (_isRelativeApiPath(filePath)) {
        // Relative API path - convert to full URL and download
        final fullUrl = _makeFullUrl(filePath!);
        await _downloadAndSaveRemoteFile(fullUrl);
      } else {
        // Local file - use existing path
        _documentFilePath = filePath;
      }

      if (mounted) {
        setState(() {
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _documentFilePath = null;
          _isLoadingPreview = false;
        });
      }
    }
  }

  Future<void> _downloadAndSaveRemoteFile(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (kIsWeb) {
          // On web, we can't save to file system, so we'll just keep the bytes in memory
          // File path will remain null, but we have the bytes for download
          _documentFilePath = null; // Indicate that file is not saved to filesystem
        } else {
          // On mobile/desktop, save to temp directory
          final tempDir = await getTemporaryDirectory();
          final tempFile = io.File('${tempDir.path}/${widget.document.name}');
          await tempFile.writeAsBytes(response.bodyBytes);
          _documentFilePath = tempFile.path;
        }
      } else {
        throw Exception('Failed to download file: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading file: $e');
    }
  }

  // Helper method to check file accessibility
  bool _isFileAccessible(String filePath) {
    if (kIsWeb) {
      // On web, we can't check file accessibility, so just return true
      return true;
    } else {
      try {
        // Check if File class is available and file exists
        io.File? platformFile;
        if (!kIsWeb) {
          platformFile = io.File(filePath);
        }
        return platformFile != null && FileUtils.existsSync(platformFile);
      } catch (e) {
        // If File class is not available or any error occurs
        return false;
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
            color: _getDocumentColor(widget.document.type).withValues(alpha: 0.1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isLoadingPreview
                  ? const Center(child: CircularProgressIndicator())
                  : _documentFilePath == null && kIsWeb
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _getDocumentIcon(widget.document.type),
                                size: 48,
                                color: _getDocumentColor(widget.document.type),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.document.type == DocumentType.pdf
                                    ? 'PDF Document'
                                    : widget.document.type == DocumentType.docx
                                        ? 'Word Document'
                                        : 'CSV Spreadsheet',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  'Web Preview Mode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _documentFilePath == null
                          ? const Center(child: Text('No preview available'))
                          : widget.document.type == DocumentType.pdf
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf,
                                        size: 48,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'PDF Document',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            final result = await OpenFile.open(_documentFilePath!);
                                            if (result.type != ResultType.done) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Could not open file: ${result.message}'),
                                                    backgroundColor: Colors.orange,
                                                  ),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error opening file: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.open_in_new, size: 16),
                                        label: const Text('Open'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: const Size(0, 28),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _buildDocumentPreview(),
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
            child: _isLoadingPreview
                ? const Center(child: CircularProgressIndicator())
                : _documentFilePath == null
                    ? const Center(child: Text('No preview available'))
                    : widget.document.type == DocumentType.pdf
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'PDF Document',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final result = await OpenFile.open(_documentFilePath!);
                                      if (result.type != ResultType.done) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Could not open file: ${result.message}'),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error opening file: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new, size: 16),
                                  label: const Text('Open'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 28),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildDocumentPreview(),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentPreview() {
    // Simple document preview for DOCX and CSV files
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.document.type == DocumentType.docx 
              ? Icons.description 
              : Icons.table_chart,
            size: 48,
            color: widget.document.type == DocumentType.docx 
              ? Colors.blue 
              : Colors.green,
          ),
          const SizedBox(height: 8),
          const Text('Document Preview'),
          const SizedBox(height: 4),
          Text(
            widget.document.type == DocumentType.docx ? 'Word Document' : 'CSV Spreadsheet',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
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
              _isFileAccessible(widget.document.filePath!) ? 'Accessible' : 'Not Found'
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
                  itemCount: activities!.length,
                  itemBuilder: (context, index) => _buildActivityItem(activities![index]),
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

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatFilePath(String path) {
    if (path.length <= 50) return path;
    return '...${path.substring(path.length - 47)}';
  }

  String _getDocumentTypeString(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return 'PDF Document';
      case DocumentType.docx:
        return 'Word Document';
      case DocumentType.csv:
        return 'CSV Spreadsheet';
      default:
        return 'Unknown';
    }
  }

  IconData _getDocumentIcon(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.docx:
        return Icons.description;
      case DocumentType.csv:
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentColor(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Colors.red;
      case DocumentType.docx:
        return Colors.blue;
      case DocumentType.csv:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'created':
        return Icons.add_circle_outline;
      case 'viewed':
        return Icons.visibility;
      case 'downloaded':
        return Icons.download;
      case 'updated':
        return Icons.edit;
      case 'deleted':
        return Icons.delete_outline;
      case 'shared':
        return Icons.share;
      case 'commented':
        return Icons.comment;
      default:
        return Icons.history;
    }
  }

  Color _getActivityColor(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'created':
        return Colors.green;
      case 'viewed':
        return Colors.blue;
      case 'downloaded':
        return Colors.orange;
      case 'updated':
        return Colors.purple;
      case 'deleted':
        return Colors.red;
      case 'shared':
        return Colors.teal;
      case 'commented':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatActivityType(String type) {
    return type.split('_').map((word) => 
      word.substring(0, 1).toUpperCase() + word.substring(1)
    ).join(' ');
  }
} 
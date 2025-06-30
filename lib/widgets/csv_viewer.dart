import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document.dart';
import '../shared/network/api_service.dart';
import '../shared/utils/logger.dart';

class CsvViewer extends StatefulWidget {
  final Document document;

  const CsvViewer({
    super.key,
    required this.document,
  });

  @override
  State<CsvViewer> createState() => _CsvViewerState();
}

class _CsvViewerState extends State<CsvViewer> {
  String? _fileUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fileUrl = widget.document.getAbsoluteFileUrl();
  }

  Future<void> _openDocument() async {
    if (_fileUrl == null) {
      _showErrorSnackBar('No file URL available for this document');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      LoggerUtil.info('Opening CSV document: $_fileUrl');
      
      final uri = Uri.parse(_fileUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LoggerUtil.info('CSV document opened successfully');
      } else {
        throw 'Could not launch $_fileUrl';
      }
    } catch (e) {
      LoggerUtil.error('Error opening CSV document: $e');
      _showErrorSnackBar('Error opening document: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with document info and open button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.table_chart,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.document.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'CSV Spreadsheet • Click to view in external application',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                ElevatedButton.icon(
                  onPressed: _fileUrl != null ? _openDocument : null,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
            ],
          ),
        ),
        
        // Document preview area
        Expanded(
          child: _buildPreviewView(),
        ),
      ],
    );
  }

  Widget _buildPreviewView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Card(
          elevation: 4,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Document icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.table_chart,
                    size: 40,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Document name
                Text(
                  widget.document.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Document type
                Text(
                  'CSV Spreadsheet',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Description
                Text(
                  'This CSV file will open in your default application for spreadsheets (like Excel or Google Sheets).',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Open button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _fileUrl != null && !_isLoading ? _openDocument : null,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.open_in_new),
                    label: Text(_isLoading ? 'Opening...' : 'Open Document'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                
                if (_fileUrl == null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'No file URL available for this document',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
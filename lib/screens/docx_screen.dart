import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:docx_viewer/docx_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DocxScreen extends StatefulWidget {
  final String url;
  final String name;
  const DocxScreen({Key? key, required this.url, required this.name})
      : super(key: key);

  @override
  _DocxScreenState createState() => _DocxScreenState();
}

class _DocxScreenState extends State<DocxScreen> {
  File? _file;
  bool _loading = true, _error = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _downloadAndSave();
  }

  Future<void> _downloadAndSave() async {
    // ── on web, skip download+temp‐file and just open externally ──
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openExternally());
      return;
    }
    
    try {
      final res = await http.get(Uri.parse(widget.url));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
      }
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/${widget.name}');
      await f.writeAsBytes(res.bodyBytes, flush: true);
      setState(() => _file = f);
    } catch (e) {
      setState(() {
        _error = true;
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openExternally() async {
    try {
      final uri = Uri.parse(widget.url);
      if (!await canLaunchUrl(uri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(kIsWeb 
                ? 'Could not open document in browser' 
                : 'Could not launch external viewer'),
            ),
          );
        }
        return;
      }
      await launchUrl(uri, mode: kIsWeb 
          ? LaunchMode.platformDefault 
          : LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb 
                ? 'Failed to open document in browser: ${e.toString()}' 
                : 'Failed to launch external viewer: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _retry() async {
    if (kIsWeb) {
      // On web, retry means trying to open externally again
      await _openExternally();
      return;
    }
    
    setState(() {
      _loading = true;
      _error = false;
      _errorMessage = '';
      _file = null;
    });
    await _downloadAndSave();
  }

  @override
  Widget build(BuildContext context) {
    // On web we never download a file; we already kicked off `openExternally`
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Opening document in browser...'),
            ],
          ),
        ),
      );
    }
    
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading document...'),
            ],
          ),
        ),
      );
    }
    
    if (_error || _file == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load ${widget.name}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _openExternally,
                    child: const Text('Open in Browser'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload document',
            onPressed: _retry,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in external app',
            onPressed: _openExternally,
          ),
        ],
      ),
      body: DocxView(filePath: _file!.path),
    );
  }
} 
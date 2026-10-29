import 'package:flutter/material.dart';
import 'package:smartclass/widgets/universal_pdf_viewer.dart';
import 'package:smartclass/services/private_storage_service.dart';

class PDFViewerPage extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PDFViewerPage({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  int _viewerVersion = 0;
  late Future<String> _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = _resolveUrl();
  }

  Future<String> _resolveUrl() async {
    final bucket = PrivateStorageService.bucketFromReference(widget.pdfUrl);
    if (bucket == null) {
      // Keep support for non-Supabase URLs used by existing callers.
      return widget.pdfUrl;
    }
    return PrivateStorageService().createSignedUrl(
      widget.pdfUrl,
      bucket: bucket,
    );
  }

  void _reload() {
    setState(() {
      _viewerVersion++;
      _resolvedUrl = _resolveUrl();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload PDF',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _resolvedUrl,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to access this file. Check your class membership and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: UniversalPdfViewer(
              key: ValueKey('${snapshot.data}-$_viewerVersion'),
              pdfUrl: snapshot.data!,
            ),
          );
        },
      ),
    );
  }
}

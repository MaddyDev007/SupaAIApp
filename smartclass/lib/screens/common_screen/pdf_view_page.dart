import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

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
  late final PdfControllerPinch _pdfController;
  bool _isLoading = true;
  bool _hasError = false;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  /// Downloads and opens the PDF efficiently.
  Future<void> _initPdf() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final uri = Uri.tryParse(widget.pdfUrl);
      if (uri == null) throw Exception('Invalid PDF URL.');

      final bytes = await http.readBytes(uri);

      final document = await PdfDocument.openData(bytes);
      _pdfController = PdfControllerPinch(document: Future.value(document));

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      debugPrint('❌ PDF load error: $e');
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload PDF',
            onPressed: _initPdf,
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
                ? _buildErrorView()
                : _buildPdfView(),
      ),
    );
  }

  /// Displays error message with retry option.
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
          const SizedBox(height: 10),
          const Text(
            'Failed to load PDF',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _initPdf,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Displays the loaded PDF with navigation controls.
  Widget _buildPdfView() {
    return Column(
      children: [
        Expanded(
          child: PdfViewPinch(
            controller: _pdfController,
            onDocumentLoaded: (details) {
              setState(() {
                _totalPages = details.pagesCount;
                _currentPage = 1;
              });
            },
            onPageChanged: (page) {
              setState(() => _currentPage = page);
            },
          ),
        ),

        // Bottom toolbar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => _pdfController.previousPage(
                          curve: Curves.ease,
                          duration: const Duration(milliseconds: 200),
                        )
                    : null,
              ),
              Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () => _pdfController.nextPage(
                          curve: Curves.ease,
                          duration: const Duration(milliseconds: 200),
                        )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

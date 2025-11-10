import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;

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
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  bool _hasError = false;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final bytes = await http.readBytes(Uri.parse(widget.pdfUrl));

      _pdfController = PdfControllerPinch(
        document: Future.value(PdfDocument.openData(bytes)),
      );

      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
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
            onPressed: _loadPdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 10),
                      const Text('Failed to load PDF.'),
                      ElevatedButton(
                        onPressed: _loadPdf,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: PdfViewPinch(
                        controller: _pdfController!,
                        onDocumentLoaded: (details) {
                          setState(() {
                            _totalPages = details.pagesCount;
                            _currentPage = 1;
                          });
                        },
                        onPageChanged: (page) {
                          setState(() {
                            _currentPage = page;
                          });
                        },
                      ),
                    ),

                    // 📍 Bottom Toolbar
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 🔽 Page Navigation
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () {
                                  if (_currentPage > 1) {
                                    _pdfController?.previousPage(
                                      curve: Curves.ease,
                                      duration:
                                          const Duration(milliseconds: 200),
                                    );
                                  }
                                },
                              ),
                              Text(
                                '$_currentPage / $_totalPages',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () {
                                  if (_currentPage < _totalPages) {
                                    _pdfController?.nextPage(
                                      curve: Curves.ease,
                                      duration:
                                          const Duration(milliseconds: 200),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),

                          // 🔍 Zoom Controls
                          /* Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.zoom_out),
                                onPressed: () => _pdfController?.zoomOut(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.zoom_in),
                                onPressed: () => _pdfController?.zoomIn(),
                              ),
                            ],
                          ), */
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
